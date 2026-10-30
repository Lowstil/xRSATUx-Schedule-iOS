import Foundation
import zlib

public final class ZIPArchive {
    public struct Entry {
        public let name: String
        public let compressionMethod: UInt16
        public let compressedSize: UInt32
        public let uncompressedSize: UInt32
        public let localHeaderOffset: UInt32
    }
    
    private let data: Data
    private var entries: [String: Entry] = [:]
    
    public init?(data: Data) {
        self.data = data
        guard parseCentralDirectory() else { return nil }
    }
    
    public convenience init?(url: URL) {
        guard let d = try? Data(contentsOf: url) else { return nil }
        self.init(data: d)
    }
    
    private func parseCentralDirectory() -> Bool {
        let count = data.count
        guard count >= 22 else { return false }
        
        // Find EOCD (End of Central Directory) signature: 0x06054b50
        var eocdOffset = -1
        let maxSearch = min(count - 22, 65557)
        let bytes = [UInt8](data)
        
        for i in stride(from: count - 22, through: count - 22 - maxSearch, by: -1) {
            if bytes[i] == 0x50 && bytes[i + 1] == 0x4B && bytes[i + 2] == 0x05 && bytes[i + 3] == 0x06 {
                eocdOffset = i
                break
            }
        }
        guard eocdOffset >= 0 else { return false }
        
        let totalEntries = Int(readUInt16(at: eocdOffset + 10))
        let cdOffset = Int(readUInt32(at: eocdOffset + 16))
        
        var pos = cdOffset
        for _ in 0..<totalEntries {
            guard pos + 46 <= count else { break }
            let sig = readUInt32(at: pos)
            guard sig == 0x02014b50 else { break }
            
            let method = readUInt16(at: pos + 10)
            let compSize = readUInt32(at: pos + 20)
            let uncompSize = readUInt32(at: pos + 24)
            let nameLen = Int(readUInt16(at: pos + 28))
            let extraLen = Int(readUInt16(at: pos + 30))
            let commentLen = Int(readUInt16(at: pos + 32))
            let localHeaderOffset = readUInt32(at: pos + 42)
            
            let nameData = data.subdata(in: (pos + 46)..<(pos + 46 + nameLen))
            let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) ?? ""
            
            entries[name] = Entry(
                name: name,
                compressionMethod: method,
                compressedSize: compSize,
                uncompressedSize: uncompSize,
                localHeaderOffset: localHeaderOffset
            )
            
            pos += 46 + nameLen + extraLen + commentLen
        }
        
        return !entries.isEmpty
    }
    
    public func extract(filename: String) -> Data? {
        guard let entry = entries[filename] else {
            // Case-insensitive fallback
            if let matchedKey = entries.keys.first(where: { $0.caseInsensitiveCompare(filename) == .orderedSame }) {
                return extract(filename: matchedKey)
            }
            return nil
        }
        
        let locOffset = Int(entry.localHeaderOffset)
        guard locOffset + 30 <= data.count else { return nil }
        
        let nameLen = Int(readUInt16(at: locOffset + 26))
        let extraLen = Int(readUInt16(at: locOffset + 28))
        let dataOffset = locOffset + 30 + nameLen + extraLen
        let dataEnd = dataOffset + Int(entry.compressedSize)
        
        guard dataEnd <= data.count else { return nil }
        let slice = data.subdata(in: dataOffset..<dataEnd)
        
        if entry.compressionMethod == 0 {
            return slice
        } else if entry.compressionMethod == 8 {
            return decompressRawDeflate(data: slice, uncompressedSize: Int(entry.uncompressedSize))
        }
        return nil
    }
    
    public var allFileNames: [String] {
        Array(entries.keys)
    }
    
    private func readUInt16(at offset: Int) -> UInt16 {
        data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
    }
    
    private func readUInt32(at offset: Int) -> UInt32 {
        data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
    }
    
    private func decompressRawDeflate(data: Data, uncompressedSize: Int) -> Data? {
        var stream = z_stream()
        // WindowBits = -15 for raw DEFLATE (RFC 1951) without zlib header
        var status = inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else { return nil }
        defer { inflateEnd(&stream) }
        
        let bufferSize = max(uncompressedSize, 65536)
        var decompressed = Data()
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        
        return data.withUnsafeBytes { rawInput in
            guard let baseAddress = rawInput.baseAddress else { return nil }
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: baseAddress.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = uInt(data.count)
            
            repeat {
                stream.avail_out = uInt(bufferSize)
                stream.next_out = &buffer
                status = inflate(&stream, Z_NO_FLUSH)
                if status != Z_OK && status != Z_STREAM_END && status != Z_BUF_ERROR {
                    return nil
                }
                let count = bufferSize - Int(stream.avail_out)
                if count > 0 {
                    decompressed.append(buffer, count: count)
                }
            } while status != Z_STREAM_END && stream.avail_in > 0
            
            return decompressed
        }
    }
}

public final class XLSXReader {
    public static let shared = XLSXReader()
    
    private init() {}
    
    private let weekRegex = try? NSRegularExpression(pattern: "\\(Недели?\\s*([^)]+)\\)", options: .caseInsensitive)
    private let typeRegex = try? NSRegularExpression(pattern: "(?<![\\p{L}0-9])(оЛ|оП|ЛР|Экзамен|Л|П)(?![\\p{L}0-9])", options: [])
    private let roomRegex = try? NSRegularExpression(pattern: "^[А-ЯЁA-Za-z]?\\d+-\\d+[а-яА-ЯёЁ]?$|^[А-ЯЁA-Za-z]+-\\d+(-\\d+)*[а-яА-ЯёЁ]?$", options: [])
    private let initialsRegex = try? NSRegularExpression(pattern: "^[А-ЯЁA-Z]\\.([А-ЯЁA-Z]\\.)?$", options: [])
    private let nameWordRegex = try? NSRegularExpression(pattern: "^[А-ЯЁA-Z][а-яёa-z]{1,}$", options: [])
    
    private let dayNames = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]
    
    // MARK: - Parse Schedule XLSX
    public func parseSchedule(xlsxURL: URL) throws -> ParsedScheduleData {
        guard let archive = ZIPArchive(url: xlsxURL) else {
            throw NSError(domain: "XLSXReader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось открыть XLSX архив"])
        }
        
        // 1. Shared Strings
        let sharedStrings = parseSharedStrings(archive: archive)
        
        // 2. Resolve Sheet files
        let (groupSheetFile, teacherSheetFile) = resolveSheetFiles(archive: archive)
        
        var groups: [String] = []
        var teachers: [String] = []
        var allItems: [ScheduleItem] = []
        
        // 3. Parse Groups Sheet
        if let gFile = groupSheetFile, let gData = archive.extract(filename: gFile),
           let gXml = String(data: gData, encoding: .utf8) {
            let (gList, gItems) = parseWorksheet(xml: gXml, sharedStrings: sharedStrings, source: "group")
            groups = gList
            allItems.append(contentsOf: gItems)
        }
        
        // 4. Parse Teachers Sheet
        if let tFile = teacherSheetFile, let tData = archive.extract(filename: tFile),
           let tXml = String(data: tData, encoding: .utf8) {
            let (tList, tItems) = parseWorksheet(xml: tXml, sharedStrings: sharedStrings, source: "teacher")
            teachers = tList
            allItems.append(contentsOf: tItems)
        }
        
        return ParsedScheduleData(
            version: "1.0",
            lastUpdated: ISO8601DateFormatter().string(from: Date()),
            semesterStart: DateUtils.isoDateFormatter.string(from: SemesterManager.getDefaultSemesterStart()),
            groups: groups.sorted(),
            teachers: teachers.sorted(),
            items: allItems
        )
    }
    
    // MARK: - Parse Shared Strings
    private func parseSharedStrings(archive: ZIPArchive) -> [String] {
        guard let data = archive.extract(filename: "xl/sharedStrings.xml"),
              let xml = String(data: data, encoding: .utf8) else {
            return []
        }
        
        var results: [String] = []
        let siRegex = try? NSRegularExpression(pattern: "<si>(.*?)</si>", options: [.dotMatchesLineSeparators])
        let tRegex = try? NSRegularExpression(pattern: "<t[^>]*>(.*?)</t>", options: [.dotMatchesLineSeparators])
        let nsXml = xml as NSString
        
        let siMatches = siRegex?.matches(in: xml, range: NSRange(location: 0, length: nsXml.length)) ?? []
        for siMatch in siMatches {
            let siContent = nsXml.substring(with: siMatch.range(at: 1))
            let nsSi = siContent as NSString
            let tMatches = tRegex?.matches(in: siContent, range: NSRange(location: 0, length: nsSi.length)) ?? []
            
            var text = ""
            for tm in tMatches {
                text += nsSi.substring(with: tm.range(at: 1))
            }
            // Decode common XML entities
            text = text.replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&apos;", with: "'")
            results.append(text)
        }
        
        return results
    }
    
    // MARK: - Resolve Sheet Names to Files
    private func resolveSheetFiles(archive: ZIPArchive) -> (groups: String?, teachers: String?) {
        guard let wbData = archive.extract(filename: "xl/workbook.xml"),
              let wbXml = String(data: wbData, encoding: .utf8) else {
            return ("xl/worksheets/sheet1.xml", "xl/worksheets/sheet3.xml")
        }
        
        // Read relationships: xl/_rels/workbook.xml.rels
        var rIdToTarget: [String: String] = [:]
        if let relData = archive.extract(filename: "xl/_rels/workbook.xml.rels"),
           let relXml = String(data: relData, encoding: .utf8) {
            let relRegex = try? NSRegularExpression(pattern: "<Relationship [^>]*Id=[\"']([^\"']+)[\"'][^>]*Target=[\"']([^\"']+)[\"']", options: [])
            let nsRel = relXml as NSString
            let matches = relRegex?.matches(in: relXml, range: NSRange(location: 0, length: nsRel.length)) ?? []
            for m in matches {
                let id = nsRel.substring(with: m.range(at: 1))
                var target = nsRel.substring(with: m.range(at: 2))
                if !target.starts(with: "xl/") {
                    target = "xl/" + target
                }
                rIdToTarget[id] = target
            }
        }
        
        let sheetRegex = try? NSRegularExpression(pattern: "<sheet [^>]*name=[\"']([^\"']+)[\"'][^>]*r:id=[\"']([^\"']+)[\"']", options: [])
        let nsWb = wbXml as NSString
        let sheetMatches = sheetRegex?.matches(in: wbXml, range: NSRange(location: 0, length: nsWb.length)) ?? []
        
        var groupFile: String? = nil
        var teacherFile: String? = nil
        
        for sm in sheetMatches {
            let name = nsWb.substring(with: sm.range(at: 1)).lowercased()
            let rId = nsWb.substring(with: sm.range(at: 2))
            let targetFile = rIdToTarget[rId] ?? ""
            
            if name.contains("групп") && !name.contains("преподават") && !name.contains("помещен") {
                groupFile = targetFile
            } else if name.contains("преподават") {
                teacherFile = targetFile
            }
        }
        
        return (groupFile ?? "xl/worksheets/sheet1.xml", teacherFile ?? "xl/worksheets/sheet3.xml")
    }
    
    // MARK: - Parse Worksheet XML
    private func parseWorksheet(xml: String, sharedStrings: [String], source: String) -> (entities: [String], items: [ScheduleItem]) {
        let nsXml = xml as NSString
        let rowRegex = try? NSRegularExpression(pattern: "<row r=[\"'](\\d+)[\"'][^>]*>(.*?)</row>", options: [.dotMatchesLineSeparators])
        let cellRegex = try? NSRegularExpression(pattern: "<c r=[\"']([A-Z]+)(\\d+)[\"'](?: [^>]*t=[\"']s[\"'][^>]*)?>.*?<v>(\\d+)</v></c>", options: [.dotMatchesLineSeparators])
        
        struct ParsedRow {
            let rowNum: Int
            let cells: [Int: String]
        }
        
        var rows: [ParsedRow] = []
        let rowMatches = rowRegex?.matches(in: xml, range: NSRange(location: 0, length: nsXml.length)) ?? []
        
        for rm in rowMatches {
            let rowNumStr = nsXml.substring(with: rm.range(at: 1))
            let rowNum = Int(rowNumStr) ?? 0
            let rowContent = nsXml.substring(with: rm.range(at: 2))
            let nsContent = rowContent as NSString
            
            let cMatches = cellRegex?.matches(in: rowContent, range: NSRange(location: 0, length: nsContent.length)) ?? []
            var cells: [Int: String] = [:]
            
            for cm in cMatches {
                let colStr = nsContent.substring(with: cm.range(at: 1))
                let valStr = nsContent.substring(with: cm.range(at: 3))
                let colIdx = colNameToIndex(colStr)
                if let valIdx = Int(valStr), valIdx >= 0 && valIdx < sharedStrings.count {
                    cells[colIdx] = sharedStrings[valIdx]
                }
            }
            rows.append(ParsedRow(rowNum: rowNum, cells: cells))
        }
        
        guard let headerRow = rows.first(where: { r in
            let c1 = r.cells[1] ?? ""
            return c1.contains("Группа") || c1.contains("Преподавател") || c1.contains("групп")
        }) else {
            return ([], [])
        }
        
        var entityColMap: [Int: String] = [:]
        for (colIdx, val) in headerRow.cells {
            if colIdx >= 3 && !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                entityColMap[colIdx] = val.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        var items: [ScheduleItem] = []
        var curWeekType: String? = nil
        var curDay: Int = -1
        
        let startIdx = rows.firstIndex(where: { $0.rowNum == headerRow.rowNum }) ?? 0
        for i in (startIdx + 1)..<rows.count {
            let r = rows[i]
            if let wtRaw = r.cells[0], !wtRaw.isEmpty {
                let low = wtRaw.lowercased()
                if low.contains("нечёт") || low.contains("нечет") { curWeekType = "odd" }
                else if low.contains("чёт") || low.contains("чет") { curWeekType = "even" }
            }
            
            if let dRaw = r.cells[1], !dRaw.isEmpty {
                for (dIdx, dName) in dayNames.enumerated() {
                    if dName.caseInsensitiveCompare(dRaw.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame {
                        curDay = dIdx + 1
                        break
                    }
                }
            }
            
            guard let lRaw = r.cells[2] else { continue }
            let dDigits = lRaw.filter { $0.isNumber }
            guard let firstDigit = dDigits.first, let lessonNum = Int(String(firstDigit)), lessonNum >= 1 && lessonNum <= 7 else {
                continue
            }
            
            guard let weekType = curWeekType, curDay >= 1 else { continue }
            
            for (colIdx, entityName) in entityColMap {
                guard let cellText = r.cells[colIdx] else { continue }
                for line in cellText.components(separatedBy: .newlines) {
                    if let item = parseLine(line: line, weekType: weekType, day: curDay, lesson: lessonNum, colName: entityName, source: source) {
                        items.append(item)
                    }
                }
            }
        }
        
        return (Array(entityColMap.values), items)
    }
    
    // MARK: - Parse Single Cell Line
    private func parseLine(line: String, weekType: String, day: Int, lesson: Int, colName: String, source: String) -> ScheduleItem? {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        
        var weekSpec = ""
        let nsText = text as NSString
        if let wm = weekRegex?.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) {
            weekSpec = nsText.substring(with: wm.range(at: 1)).replacingOccurrences(of: " ", with: "")
            text = (nsText.replacingCharacters(in: wm.range, with: " ") as NSString).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        var type = "Л"
        var subjectRaw: String? = nil
        var tail = text
        let nsText2 = text as NSString
        if let tm = typeRegex?.firstMatch(in: text, range: NSRange(location: 0, length: nsText2.length)) {
            type = nsText2.substring(with: tm.range(at: 1))
            subjectRaw = nsText2.substring(to: tm.range.location).trimmingCharacters(in: .whitespacesAndNewlines)
            tail = nsText2.substring(from: tm.range.location + tm.range.length).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        var tokens = tail.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var room = ""
        
        if tokens.count >= 3 {
            let three = tokens[(tokens.count - 3)...].joined(separator: " ")
            if three.lowercased().contains("криста") {
                room = three
                tokens.removeLast(3)
            }
        }
        if room.isEmpty && tokens.count >= 2 {
            let two = tokens[(tokens.count - 2)...].joined(separator: " ")
            if two.caseInsensitiveCompare("Большой спортзал") == .orderedSame || two.caseInsensitiveCompare("Точка кипения") == .orderedSame {
                room = two
                tokens.removeLast(2)
            }
        }
        if room.isEmpty && tokens.count >= 1 {
            let last = tokens.last!
            let nsLast = last as NSString
            if last.lowercased() == "онлайн" || last.lowercased() == "saby" || last.lowercased() == "предприятия" ||
               (roomRegex?.firstMatch(in: last, range: NSRange(location: 0, length: nsLast.length)) != nil) {
                room = last
                tokens.removeLast()
            }
        }
        
        var teacher = ""
        var groupName = colName
        
        if source == "group" {
            teacher = tokens.joined(separator: " ")
        } else {
            teacher = colName
            groupName = tokens.first ?? ""
        }
        
        var subject = subjectRaw ?? text
        // Clean subject token prefix (e.g. РПИ-21)
        if let firstToken = subject.components(separatedBy: .whitespaces).first,
           firstToken.contains("-") && firstToken.first?.isLetter == true {
            let dropCount = firstToken.count
            subject = String(subject.dropFirst(dropCount)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if subject.isEmpty { subject = text }
        
        return ScheduleItem(
            weekType: weekType,
            dayOfWeek: day,
            lessonNumber: lesson,
            groupName: groupName,
            teacherName: teacher,
            subjectName: subject,
            lessonType: type,
            room: room.isEmpty ? "Г-100" : room,
            weekSpec: weekSpec,
            source: source
        )
    }
    
    private func colNameToIndex(_ colName: String) -> Int {
        var index = 0
        for scalar in colName.unicodeScalars {
            index = index * 26 + (Int(scalar.value) - 64)
        }
        return index - 1
    }
}
