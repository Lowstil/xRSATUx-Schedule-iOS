import Foundation

public enum ScheduleChangeKind: String, Codable, Hashable {
    case added
    case removed
    case roomChanged
    case teacherChanged
}

public struct ScheduleChange: Codable, Identifiable, Hashable {
    public var id: String
    public var kind: ScheduleChangeKind
    public var weekType: String
    public var dayOfWeek: Int
    public var lessonNumber: Int
    public var subjectName: String
    public var lessonType: String
    public var oldValue: String?
    public var newValue: String?
    
    public init(
        id: String? = nil,
        kind: ScheduleChangeKind,
        weekType: String,
        dayOfWeek: Int,
        lessonNumber: Int,
        subjectName: String,
        lessonType: String,
        oldValue: String? = nil,
        newValue: String? = nil
    ) {
        self.id = id ?? "\(kind.rawValue)#\(weekType)#\(dayOfWeek)#\(lessonNumber)#\(subjectName.lowercased())#\(lessonType.lowercased())"
        self.kind = kind
        self.weekType = weekType
        self.dayOfWeek = dayOfWeek
        self.lessonNumber = lessonNumber
        self.subjectName = subjectName
        self.lessonType = lessonType
        self.oldValue = oldValue
        self.newValue = newValue
    }
}

public struct ScheduleDiffResult: Codable, Equatable {
    public var targetName: String
    public var isGroup: Bool
    public var detectedAt: Date
    public var changes: [ScheduleChange]
    
    public init(
        targetName: String,
        isGroup: Bool,
        detectedAt: Date = Date(),
        changes: [ScheduleChange] = []
    ) {
        self.targetName = targetName
        self.isGroup = isGroup
        self.detectedAt = detectedAt
        self.changes = changes
    }
    
    public var isEmpty: Bool {
        changes.isEmpty
    }
    
    public var summaryText: String {
        if changes.isEmpty {
            return "Изменений в расписании не обнаружено"
        }
        let added = changes.filter { $0.kind == .added }.count
        let removed = changes.filter { $0.kind == .removed }.count
        let room = changes.filter { $0.kind == .roomChanged }.count
        let teacher = changes.filter { $0.kind == .teacherChanged }.count
        
        var parts: [String] = []
        if added > 0 { parts.append("+\(added) добавл.") }
        if removed > 0 { parts.append("-\(removed) отмен.") }
        if room > 0 { parts.append("\(room) ауд.") }
        if teacher > 0 { parts.append("\(teacher) \(isGroup ? "преп." : "гр.")") }
        
        return "Изменений: \(changes.count) (\(parts.joined(separator: ", ")))"
    }
}

public enum ScheduleDiffComputer {
    public static func computeDiff(
        oldItems: [ScheduleItem],
        newItems: [ScheduleItem],
        targetName: String,
        isGroup: Bool
    ) -> ScheduleDiffResult {
        var oldGrouped: [String: [ScheduleItem]] = [:]
        for item in oldItems {
            oldGrouped[itemKey(item), default: []].append(item)
        }
        
        var newGrouped: [String: [ScheduleItem]] = [:]
        for item in newItems {
            newGrouped[itemKey(item), default: []].append(item)
        }
        
        let allKeys = Set(oldGrouped.keys).union(newGrouped.keys)
        var changes: [ScheduleChange] = []
        
        for key in allKeys {
            var oldList = sortBucket(oldGrouped[key] ?? [])
            var newList = sortBucket(newGrouped[key] ?? [])
            
            // Remove identical items first so subgroup shifts don't emit false diffs
            var unmatchedOld: [ScheduleItem] = []
            for oldItem in oldList {
                if let matchIdx = newList.firstIndex(where: { itemsMatchDetails($0, oldItem, isGroup: isGroup) }) {
                    newList.remove(at: matchIdx)
                } else {
                    unmatchedOld.append(oldItem)
                }
            }
            oldList = unmatchedOld
            
            let pairedCount = min(oldList.count, newList.count)
            for idx in 0..<pairedCount {
                let oldItem = oldList[idx]
                let newItem = newList[idx]
                
                let oldRoom = oldItem.room.trimmingCharacters(in: .whitespacesAndNewlines)
                let newRoom = newItem.room.trimmingCharacters(in: .whitespacesAndNewlines)
                if oldRoom.caseInsensitiveCompare(newRoom) != .orderedSame {
                    changes.append(
                        ScheduleChange(
                            id: "roomChanged#\(key)#\(idx)",
                            kind: .roomChanged,
                            weekType: newItem.weekType,
                            dayOfWeek: newItem.dayOfWeek,
                            lessonNumber: newItem.lessonNumber,
                            subjectName: newItem.subjectName,
                            lessonType: newItem.lessonType,
                            oldValue: oldRoom.isEmpty ? nil : oldRoom,
                            newValue: newRoom.isEmpty ? nil : newRoom
                        )
                    )
                }
                
                let oldOwner = (isGroup ? oldItem.teacherName : oldItem.groupName)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let newOwner = (isGroup ? newItem.teacherName : newItem.groupName)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if oldOwner.caseInsensitiveCompare(newOwner) != .orderedSame {
                    changes.append(
                        ScheduleChange(
                            id: "teacherChanged#\(key)#\(idx)",
                            kind: .teacherChanged,
                            weekType: newItem.weekType,
                            dayOfWeek: newItem.dayOfWeek,
                            lessonNumber: newItem.lessonNumber,
                            subjectName: newItem.subjectName,
                            lessonType: newItem.lessonType,
                            oldValue: oldOwner.isEmpty ? nil : oldOwner,
                            newValue: newOwner.isEmpty ? nil : newOwner
                        )
                    )
                }
            }
            
            if oldList.count > pairedCount {
                for idx in pairedCount..<oldList.count {
                    let oldItem = oldList[idx]
                    let room = oldItem.room.trimmingCharacters(in: .whitespacesAndNewlines)
                    changes.append(
                        ScheduleChange(
                            id: "removed#\(key)#\(idx)",
                            kind: .removed,
                            weekType: oldItem.weekType,
                            dayOfWeek: oldItem.dayOfWeek,
                            lessonNumber: oldItem.lessonNumber,
                            subjectName: oldItem.subjectName,
                            lessonType: oldItem.lessonType,
                            oldValue: room.isEmpty ? nil : room,
                            newValue: nil
                        )
                    )
                }
            }
            
            if newList.count > pairedCount {
                for idx in pairedCount..<newList.count {
                    let newItem = newList[idx]
                    let room = newItem.room.trimmingCharacters(in: .whitespacesAndNewlines)
                    changes.append(
                        ScheduleChange(
                            id: "added#\(key)#\(idx)",
                            kind: .added,
                            weekType: newItem.weekType,
                            dayOfWeek: newItem.dayOfWeek,
                            lessonNumber: newItem.lessonNumber,
                            subjectName: newItem.subjectName,
                            lessonType: newItem.lessonType,
                            oldValue: nil,
                            newValue: room.isEmpty ? nil : room
                        )
                    )
                }
            }
        }
        
        changes.sort { a, b in
            if a.weekType != b.weekType { return a.weekType < b.weekType }
            if a.dayOfWeek != b.dayOfWeek { return a.dayOfWeek < b.dayOfWeek }
            if a.lessonNumber != b.lessonNumber { return a.lessonNumber < b.lessonNumber }
            let subjCmp = a.subjectName.localizedCaseInsensitiveCompare(b.subjectName)
            if subjCmp != .orderedSame { return subjCmp == .orderedAscending }
            if a.kind.rawValue != b.kind.rawValue { return a.kind.rawValue < b.kind.rawValue }
            return a.id < b.id
        }
        
        return ScheduleDiffResult(
            targetName: targetName,
            isGroup: isGroup,
            detectedAt: Date(),
            changes: changes
        )
    }
    
    private static func itemKey(_ item: ScheduleItem) -> String {
        let wt = item.weekType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let subj = item.subjectName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let type = item.lessonType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(wt)#\(item.dayOfWeek)#\(item.lessonNumber)#\(subj)#\(type)"
    }
    
    private static func itemsMatchDetails(_ a: ScheduleItem, _ b: ScheduleItem, isGroup: Bool) -> Bool {
        let rA = a.room.trimmingCharacters(in: .whitespacesAndNewlines)
        let rB = b.room.trimmingCharacters(in: .whitespacesAndNewlines)
        let oA = (isGroup ? a.teacherName : a.groupName).trimmingCharacters(in: .whitespacesAndNewlines)
        let oB = (isGroup ? b.teacherName : b.groupName).trimmingCharacters(in: .whitespacesAndNewlines)
        return rA.caseInsensitiveCompare(rB) == .orderedSame &&
            oA.caseInsensitiveCompare(oB) == .orderedSame
    }
    
    private static func sortBucket(_ list: [ScheduleItem]) -> [ScheduleItem] {
        list.sorted { a, b in
            if a.room != b.room { return a.room < b.room }
            if a.teacherName != b.teacherName { return a.teacherName < b.teacherName }
            if a.groupName != b.groupName { return a.groupName < b.groupName }
            return a.weekSpec < b.weekSpec
        }
    }
}
