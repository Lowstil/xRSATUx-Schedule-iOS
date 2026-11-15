import Foundation
import Combine

public final class ScheduleRepository: ObservableObject {
    public static let shared = ScheduleRepository()
    
    @Published public private(set) var allItems: [ScheduleItem] = []
    @Published public private(set) var groups: [String] = []
    @Published public private(set) var teachers: [String] = []
    @Published public private(set) var favorites: [GroupOrTeacher] = []
    @Published public private(set) var notes: [LessonNote] = []
    @Published public private(set) var lastUpdated: Date? = nil
    @Published public private(set) var isUpdating: Bool = false
    @Published public private(set) var updateErrorMessage: String? = nil
    @Published public private(set) var lastScheduleDiff: ScheduleDiffResult? = nil
    
    private let userDefaults: UserDefaults
    private let scheduleFilter = ScheduleFilter()
    
    private let cacheFileName = "schedule_data.json"
    private var cacheFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(cacheFileName)
    }
    
    private var cachedXLSXURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(Constants.scheduleCacheFileName)
    }
    
    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadFromCacheOrBundle()
        loadFavorites()
        loadNotes()
        loadScheduleDiff()
        
        // Auto-refresh in background if due (similar to SplashActivity / MainActivity in Android)
        Task {
            await maybeAutoRefresh()
        }
    }
    
    // MARK: - Initial Load
    public func loadFromCacheOrBundle() {
        // 1. Try saved parsed JSON in Documents
        if FileManager.default.fileExists(atPath: cacheFileURL.path),
           let data = try? Data(contentsOf: cacheFileURL),
           let parsed = try? ScheduleParser.shared.parseScheduleJSON(data: data),
           !parsed.items.isEmpty {
            applyParsedData(parsed)
            return
        }
        
        // 2. Try parsing cached .xlsx if exists in Documents
        if FileManager.default.fileExists(atPath: cachedXLSXURL.path),
           let parsed = try? XLSXReader.shared.parseSchedule(xlsxURL: cachedXLSXURL),
           !parsed.items.isEmpty {
            applyParsedData(parsed)
            saveParsedDataToCache(parsed)
            return
        }
        
        // 3. Fallback to bundled SampleSchedule.json
        if let sample = ScheduleParser.shared.loadBundledSampleSchedule(), !sample.items.isEmpty {
            applyParsedData(sample)
            return
        }
        
        // 4. Fallback to bundled schedule.xlsx
        if let bundleXlsx = Bundle.main.url(forResource: "schedule", withExtension: "xlsx"),
           let parsed = try? XLSXReader.shared.parseSchedule(xlsxURL: bundleXlsx) {
            applyParsedData(parsed)
            saveParsedDataToCache(parsed)
        }
    }
    
    private func applyParsedData(_ data: ParsedScheduleData) {
        self.allItems = data.items
        self.groups = data.groups.sorted()
        self.teachers = data.teachers.sorted()
        if let lu = ISO8601DateFormatter().date(from: data.lastUpdated) {
            self.lastUpdated = lu
        } else if let savedDate = userDefaults.object(forKey: Constants.prefLastUpdated) as? Date {
            self.lastUpdated = savedDate
        } else {
            self.lastUpdated = Date()
        }
    }
    
    private func saveParsedDataToCache(_ data: ParsedScheduleData) {
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: cacheFileURL, options: .atomic)
            userDefaults.set(Date(), forKey: Constants.prefLastUpdated)
        }
    }
    
    // MARK: - Auto-Refresh Logic (Matches Android shouldAutoRefresh)
    public func shouldAutoRefresh() -> Bool {
        if allItems.isEmpty { return true }
        guard let lu = lastUpdated else { return true }
        let hours = Calendar.current.dateComponents([.hour], from: lu, to: Date()).hour ?? 0
        return hours >= 24
    }
    
    public func maybeAutoRefresh() async {
        guard shouldAutoRefresh() else { return }
        do {
            try await refreshSchedule()
        } catch {
            print("Auto-refresh failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Remote Refresh (Downloads & Parses .xlsx from rsatu.ru)
    public func refreshSchedule() async throws {
        await MainActor.run {
            self.isUpdating = true
            self.updateErrorMessage = nil
        }
        defer {
            Task { @MainActor in self.isUpdating = false }
        }
        
        // 1. Download schedule.xlsx
        try await NetworkService.shared.fetchScheduleFile(cacheURL: cachedXLSXURL)
        
        // 2. Parse downloaded schedule.xlsx
        let parsed = try XLSXReader.shared.parseSchedule(xlsxURL: cachedXLSXURL)
        guard !parsed.items.isEmpty else {
            throw NSError(domain: "ScheduleRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Файл расписания пуст или не содержит занятий"])
        }
        
        // 3. Save parsed data to local JSON cache for fast launch
        saveParsedDataToCache(parsed)
        
        // 4. Snapshot old target items, update memory state, and compute diff on MainActor
        await MainActor.run {
            let savedName = (self.userDefaults.string(forKey: Constants.prefSelectionName) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let savedIsGroup = (self.userDefaults.string(forKey: Constants.prefSelectionType) ?? "group") == "group"
            let shouldComputeDiff = !self.allItems.isEmpty && !savedName.isEmpty
            let oldTargetItems = shouldComputeDiff ? self.getSchedule(for: savedName, isGroup: savedIsGroup) : []
            
            self.applyParsedData(parsed)
            self.lastUpdated = Date()
            
            if shouldComputeDiff {
                let newTargetItems = self.getSchedule(for: savedName, isGroup: savedIsGroup)
                let diff = ScheduleDiffComputer.computeDiff(
                    oldItems: oldTargetItems,
                    newItems: newTargetItems,
                    targetName: savedName,
                    isGroup: savedIsGroup
                )
                if !diff.isEmpty {
                    self.saveScheduleDiff(diff)
                }
            }
        }
        
        // 5. Download transfers.xlsx (optional, failure doesn't block main schedule)
        let transfersCacheURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Constants.transfersCacheFileName)
        do {
            try await NetworkService.shared.fetchTransfersFile(cacheURL: transfersCacheURL)
        } catch {
            print("Transfers fetch warning: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Schedule Diff Persistence
    private func loadScheduleDiff() {
        guard let data = userDefaults.data(forKey: Constants.prefScheduleDiffData),
              let decoded = try? JSONDecoder().decode(ScheduleDiffResult.self, from: data),
              !decoded.isEmpty else {
            self.lastScheduleDiff = nil
            return
        }
        self.lastScheduleDiff = decoded
    }
    
    private func saveScheduleDiff(_ diff: ScheduleDiffResult) {
        guard !diff.isEmpty else { return }
        if let encoded = try? JSONEncoder().encode(diff) {
            userDefaults.set(encoded, forKey: Constants.prefScheduleDiffData)
        }
        self.lastScheduleDiff = diff
    }
    
    public func clearScheduleDiff() {
        userDefaults.removeObject(forKey: Constants.prefScheduleDiffData)
        if Thread.isMainThread {
            self.lastScheduleDiff = nil
        } else {
            DispatchQueue.main.async {
                self.lastScheduleDiff = nil
            }
        }
    }
    
    // MARK: - Query Schedule
    public func getSchedule(for targetName: String, isGroup: Bool) -> [ScheduleItem] {
        let clean = targetName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return [] }
        
        let excluded = getExcludedSubjects(for: targetName)
        let todayStr = DateUtils.isoDateFormatter.string(from: Date())
        
        return allItems.filter { item in
            let match = isGroup
                ? item.groupName.lowercased() == clean
                : item.teacherName.lowercased().contains(clean)
            return match
        }.map { item in
            var copy = item
            if excluded.contains(item.subjectName) {
                copy.isExcluded = true
            }
            if self.isLessonSkipped(dateString: todayStr, lessonNumber: item.lessonNumber, subject: item.subjectName) {
                copy.isSkipped = true
            }
            return copy
        }
    }
    
    // MARK: - Next Upcoming Lesson
    public func findNextLesson(
        targetName: String,
        isGroup: Bool,
        weekCalculator: WeekCalculator,
        fromDate: Date = Date(),
        maxDaysAhead: Int = 14
    ) -> NextLesson? {
        let clean = targetName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }
        
        let excluded = getExcludedSubjects(for: targetName)
        let targetItems = allItems.filter { item in
            isGroup
                ? item.groupName.lowercased() == clean
                : item.teacherName.lowercased().contains(clean)
        }
        guard !targetItems.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let nowTimeStr = DateUtils.timeFormatter.string(from: fromDate)
        
        for dayOffset in 0...maxDaysAhead {
            guard let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: fromDate) else { continue }
            if HolidayChecker.shared.isDayOff(date: checkDate) { continue }
            
            let dow = DateUtils.toScheduleDayOfWeek(date: checkDate)
            guard dow >= 1 && dow <= 6 else { continue }
            
            let weekNum = weekCalculator.getWeekNumber(for: checkDate)
            guard weekNum > 0, let weekType = weekCalculator.getWeekType(for: checkDate) else { continue }
            let checkDateStr = DateUtils.isoDateFormatter.string(from: checkDate)
            
            let dayLessons = targetItems.filter { item in
                guard item.dayOfWeek == dow,
                      item.weekType.lowercased() == weekType.lowercased(),
                      item.isActiveOnWeek(weekNum),
                      !item.isCancelled,
                      !excluded.contains(item.subjectName) else {
                    return false
                }
                return !self.isLessonSkipped(dateString: checkDateStr, lessonNumber: item.lessonNumber, subject: item.subjectName)
            }.sorted(by: { $0.lessonNumber < $1.lessonNumber })
            
            let times = Constants.getLessonTimes(dayOfWeek: dow)
            
            for item in dayLessons {
                guard item.lessonNumber >= 1 && item.lessonNumber <= times.count else { continue }
                let timePair = times[item.lessonNumber - 1]
                
                if dayOffset == 0 && timePair.start <= nowTimeStr {
                    continue
                }
                
                return NextLesson(
                    subjectName: item.subjectName,
                    lessonType: item.lessonType,
                    room: item.room,
                    teacherOrGroup: isGroup ? item.teacherName : item.groupName,
                    date: checkDate,
                    lessonNumber: item.lessonNumber,
                    timeStart: timePair.start,
                    timeEnd: timePair.end
                )
            }
        }
        return nil
    }
    
    // MARK: - Teacher & Room Finder Queries
    public func getAllTeacherNames() -> [String] {
        var seen: [String: String] = [:]
        let separators = CharacterSet(charactersIn: ",;/")
        
        let ingest: (String) -> Void = { raw in
            for part in raw.components(separatedBy: separators) {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != "-", trimmed != "—" else { continue }
                let key = trimmed.lowercased()
                if seen[key] == nil {
                    seen[key] = trimmed
                }
            }
        }
        
        for t in teachers {
            ingest(t)
        }
        for item in allItems {
            ingest(item.teacherName)
        }
        
        return seen.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    public func getLessonsForTeacher(_ teacher: String, weekType: String, dayOfWeek: Int) -> [ScheduleItem] {
        let clean = teacher.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return [] }
        
        let wt = weekType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var seenSignatures = Set<String>()
        
        return allItems.filter { item in
            !item.isCancelled &&
            item.dayOfWeek == dayOfWeek &&
            item.weekType.lowercased() == wt &&
            item.teacherName.lowercased().contains(clean)
        }
        .sorted { a, b in
            if a.lessonNumber != b.lessonNumber { return a.lessonNumber < b.lessonNumber }
            return a.groupName.localizedCaseInsensitiveCompare(b.groupName) == .orderedAscending
        }
        .filter { item in
            let sig = "\(item.lessonNumber)#\(item.subjectName.lowercased())#\(item.groupName.lowercased())#\(item.room.lowercased())"
            return seenSignatures.insert(sig).inserted
        }
    }
    
    public func getAllDistinctRooms(buildingFilter: String? = nil) -> [String] {
        var seen: [String: String] = [:]
        
        for item in allItems {
            let room = item.room.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isPhysicalRoom(room), matchesBuildingFilter(room, filter: buildingFilter) else { continue }
            let key = room.lowercased()
            if seen[key] == nil {
                seen[key] = room
            }
        }
        
        return seen.values.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    
    public func getFreeRooms(weekType: String, dayOfWeek: Int, lessonNumber: Int, buildingFilter: String? = nil) -> [String] {
        let distinctRooms = getAllDistinctRooms(buildingFilter: buildingFilter)
        let wt = weekType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        var occupied = Set<String>()
        for item in allItems {
            guard !item.isCancelled,
                  item.dayOfWeek == dayOfWeek,
                  item.lessonNumber == lessonNumber,
                  item.weekType.lowercased() == wt else {
                continue
            }
            let room = item.room.trimmingCharacters(in: .whitespacesAndNewlines)
            if !room.isEmpty {
                occupied.insert(room.lowercased())
            }
        }
        
        return distinctRooms.filter { !occupied.contains($0.lowercased()) }
    }
    
    private func isPhysicalRoom(_ room: String) -> Bool {
        guard !room.isEmpty, room != "-", room != "—" else { return false }
        let low = room.lowercased()
        let onlineMarkers = ["онлайн", "online", "saby", "дистант", "сдо"]
        return !onlineMarkers.contains(where: { low.contains($0) })
    }
    
    private func matchesBuildingFilter(_ room: String, filter: String?) -> Bool {
        guard let rawFilter = filter?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawFilter.isEmpty,
              rawFilter.caseInsensitiveCompare("Все") != .orderedSame else {
            return true
        }
        let upperRoom = room.uppercased()
        let upperFilter = rawFilter.uppercased()
        if upperFilter == "Г" {
            return upperRoom.hasPrefix("Г")
        }
        return upperRoom.hasPrefix("\(upperFilter)-") ||
            upperRoom.hasPrefix("\(upperFilter) ") ||
            upperRoom == upperFilter ||
            upperRoom.hasPrefix(upperFilter)
    }
    
    // MARK: - Favorites
    public func loadFavorites() {
        if let data = userDefaults.data(forKey: Constants.prefFavorites),
           let list = try? JSONDecoder().decode([GroupOrTeacher].self, from: data) {
            self.favorites = list
        } else {
            self.favorites = [
                GroupOrTeacher(name: "ИВБ-24", type: .group, isFavorite: true),
                GroupOrTeacher(name: "ДТБ-23", type: .group, isFavorite: true),
                GroupOrTeacher(name: "Башкин М.А.", type: .teacher, isFavorite: true)
            ]
        }
    }
    
    public func isFavorite(name: String, type: SelectionType) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return favorites.contains { $0.name.lowercased() == clean && $0.type == type }
    }
    
    public func toggleFavorite(name: String, type: SelectionType) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = favorites.firstIndex(where: { $0.name.lowercased() == clean.lowercased() && $0.type == type }) {
            favorites.remove(at: idx)
        } else {
            favorites.append(GroupOrTeacher(name: clean, type: type, isFavorite: true))
        }
        if let data = try? JSONEncoder().encode(favorites) {
            userDefaults.set(data, forKey: Constants.prefFavorites)
        }
    }
    
    // MARK: - Notes (Homework / Tasks)
    public func loadNotes() {
        if let data = userDefaults.data(forKey: "lesson_notes_list"),
           let list = try? JSONDecoder().decode([LessonNote].self, from: data) {
            self.notes = list
        }
    }
    
    public func getNote(dateString: String, lessonNumber: Int, subject: String) -> LessonNote? {
        notes.first { $0.dateString == dateString && $0.lessonNumber == lessonNumber && $0.subjectName == subject }
    }
    
    public func saveNote(_ note: LessonNote) {
        if let idx = notes.firstIndex(where: { $0.dateString == note.dateString && $0.lessonNumber == note.lessonNumber && $0.subjectName == note.subjectName }) {
            notes[idx] = note
        } else {
            notes.append(note)
        }
        persistNotes()
    }
    
    public func toggleNoteCompleted(id: UUID) {
        if let idx = notes.firstIndex(where: { $0.id == id }) {
            notes[idx].isCompleted.toggle()
            persistNotes()
        }
    }
    
    public func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
        persistNotes()
    }
    
    private func persistNotes() {
        if let data = try? JSONEncoder().encode(notes) {
            userDefaults.set(data, forKey: "lesson_notes_list")
        }
    }
    
    // MARK: - Attendance & Skipped Lessons ("Н-ки" и "Посещено")
    private func buildAttendanceKey(dateString: String, lessonNumber: Int, subject: String) -> String {
        return "\(dateString)#\(lessonNumber)#\(subject.trimmingCharacters(in: .whitespacesAndNewlines))"
    }
    
    public func isLessonSkipped(dateString: String, lessonNumber: Int, subject: String) -> Bool {
        let set = Set(userDefaults.stringArray(forKey: Constants.prefSkippedLessons) ?? [])
        let exact = buildAttendanceKey(dateString: dateString, lessonNumber: lessonNumber, subject: subject)
        if set.contains(exact) { return true }
        let shortKey = "\(dateString)#\(lessonNumber)#"
        return set.contains(where: { $0.hasPrefix(shortKey) })
    }
    
    public func isLessonAttended(dateString: String, lessonNumber: Int, subject: String) -> Bool {
        let set = Set(userDefaults.stringArray(forKey: Constants.prefAttendedLessons) ?? [])
        let exact = buildAttendanceKey(dateString: dateString, lessonNumber: lessonNumber, subject: subject)
        if set.contains(exact) { return true }
        let shortKey = "\(dateString)#\(lessonNumber)#"
        return set.contains(where: { $0.hasPrefix(shortKey) })
    }
    
    public func getAttendanceStatus(dateString: String, lessonNumber: Int, subject: String) -> AttendanceStatus {
        if isLessonSkipped(dateString: dateString, lessonNumber: lessonNumber, subject: subject) {
            return .skipped
        }
        if isLessonAttended(dateString: dateString, lessonNumber: lessonNumber, subject: subject) {
            return .attended
        }
        return .none
    }
    
    public func markLessonSkipped(dateString: String, lessonNumber: Int, subject: String) {
        let exact = buildAttendanceKey(dateString: dateString, lessonNumber: lessonNumber, subject: subject)
        let shortKey = "\(dateString)#\(lessonNumber)#"
        
        var skippedSet = Set(userDefaults.stringArray(forKey: Constants.prefSkippedLessons) ?? [])
        var attendedSet = Set(userDefaults.stringArray(forKey: Constants.prefAttendedLessons) ?? [])
        
        skippedSet = skippedSet.filter { $0 != exact && !$0.hasPrefix(shortKey) }
        attendedSet = attendedSet.filter { $0 != exact && !$0.hasPrefix(shortKey) }
        
        skippedSet.insert(exact)
        userDefaults.set(Array(skippedSet), forKey: Constants.prefSkippedLessons)
        userDefaults.set(Array(attendedSet), forKey: Constants.prefAttendedLessons)
        NotificationCenter.default.post(name: NSNotification.Name("AttendanceChanged"), object: nil)
    }
    
    public func markLessonAttended(dateString: String, lessonNumber: Int, subject: String) {
        let exact = buildAttendanceKey(dateString: dateString, lessonNumber: lessonNumber, subject: subject)
        let shortKey = "\(dateString)#\(lessonNumber)#"
        
        var skippedSet = Set(userDefaults.stringArray(forKey: Constants.prefSkippedLessons) ?? [])
        var attendedSet = Set(userDefaults.stringArray(forKey: Constants.prefAttendedLessons) ?? [])
        
        skippedSet = skippedSet.filter { $0 != exact && !$0.hasPrefix(shortKey) }
        attendedSet = attendedSet.filter { $0 != exact && !$0.hasPrefix(shortKey) }
        
        attendedSet.insert(exact)
        userDefaults.set(Array(skippedSet), forKey: Constants.prefSkippedLessons)
        userDefaults.set(Array(attendedSet), forKey: Constants.prefAttendedLessons)
        NotificationCenter.default.post(name: NSNotification.Name("AttendanceChanged"), object: nil)
    }
    
    public func clearLessonAttendance(dateString: String, lessonNumber: Int, subject: String) {
        let exact = buildAttendanceKey(dateString: dateString, lessonNumber: lessonNumber, subject: subject)
        let shortKey = "\(dateString)#\(lessonNumber)#"
        
        var skippedSet = Set(userDefaults.stringArray(forKey: Constants.prefSkippedLessons) ?? [])
        var attendedSet = Set(userDefaults.stringArray(forKey: Constants.prefAttendedLessons) ?? [])
        
        skippedSet = skippedSet.filter { $0 != exact && !$0.hasPrefix(shortKey) }
        attendedSet = attendedSet.filter { $0 != exact && !$0.hasPrefix(shortKey) }
        
        userDefaults.set(Array(skippedSet), forKey: Constants.prefSkippedLessons)
        userDefaults.set(Array(attendedSet), forKey: Constants.prefAttendedLessons)
        NotificationCenter.default.post(name: NSNotification.Name("AttendanceChanged"), object: nil)
    }
    
    public func toggleLessonSkipped(dateString: String, lessonNumber: Int, subject: String) -> Bool {
        if isLessonSkipped(dateString: dateString, lessonNumber: lessonNumber, subject: subject) {
            clearLessonAttendance(dateString: dateString, lessonNumber: lessonNumber, subject: subject)
            return false
        } else {
            markLessonSkipped(dateString: dateString, lessonNumber: lessonNumber, subject: subject)
            return true
        }
    }
    
    // Manual adjustments (+/- skips for subject)
    public func getManualAdjustment(group: String, subject: String) -> Int {
        let key = "\(Constants.prefAttendanceManualPrefix)\(group.trimmingCharacters(in: .whitespacesAndNewlines))_\(subject.trimmingCharacters(in: .whitespacesAndNewlines))"
        return userDefaults.integer(forKey: key)
    }
    
    public func adjustManualSkips(group: String, subject: String, delta: Int) {
        let key = "\(Constants.prefAttendanceManualPrefix)\(group.trimmingCharacters(in: .whitespacesAndNewlines))_\(subject.trimmingCharacters(in: .whitespacesAndNewlines))"
        let current = userDefaults.integer(forKey: key)
        userDefaults.set(current + delta, forKey: key)
        NotificationCenter.default.post(name: NSNotification.Name("AttendanceChanged"), object: nil)
    }
    
    // MARK: - Excluded Subjects ("Перезачёт")
    public func isSubjectExcluded(group: String, subject: String) -> Bool {
        let key = Constants.prefExcludedSubjectsPrefix + group.trimmingCharacters(in: .whitespacesAndNewlines)
        let set = Set(userDefaults.stringArray(forKey: key) ?? [])
        return set.contains(subject.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    public func getExcludedSubjects(for group: String) -> Set<String> {
        let key = Constants.prefExcludedSubjectsPrefix + group.trimmingCharacters(in: .whitespacesAndNewlines)
        return Set(userDefaults.stringArray(forKey: key) ?? [])
    }
    
    public func toggleExcludedSubject(group: String, subject: String) {
        let key = Constants.prefExcludedSubjectsPrefix + group.trimmingCharacters(in: .whitespacesAndNewlines)
        var set = getExcludedSubjects(for: group)
        if set.contains(subject) {
            set.remove(subject)
        } else {
            set.insert(subject)
        }
        userDefaults.set(Array(set), forKey: key)
    }
}
