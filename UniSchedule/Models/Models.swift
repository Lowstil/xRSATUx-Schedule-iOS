import Foundation

public struct LessonNote: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var dateString: String // "yyyy-MM-dd"
    public var lessonNumber: Int
    public var subjectName: String
    public var noteText: String
    public var imagePath: String? = nil
    public var isCompleted: Bool = false
    public var createdAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case id
        case dateString
        case lessonNumber
        case subjectName
        case noteText
        case imagePath
        case isCompleted
        case createdAt
    }

    public init(
        id: UUID = UUID(),
        dateString: String,
        lessonNumber: Int,
        subjectName: String,
        noteText: String,
        imagePath: String? = nil,
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.dateString = dateString
        self.lessonNumber = lessonNumber
        self.subjectName = subjectName
        self.noteText = noteText
        self.imagePath = imagePath
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.dateString = try c.decodeIfPresent(String.self, forKey: .dateString) ?? ""
        self.lessonNumber = try c.decodeIfPresent(Int.self, forKey: .lessonNumber) ?? 1
        self.subjectName = try c.decodeIfPresent(String.self, forKey: .subjectName) ?? ""
        self.noteText = try c.decodeIfPresent(String.self, forKey: .noteText) ?? ""
        self.imagePath = try c.decodeIfPresent(String.self, forKey: .imagePath)
        self.isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        if let decodedDate = try? c.decodeIfPresent(Date.self, forKey: .createdAt) {
            self.createdAt = decodedDate
        } else if let str = try? c.decodeIfPresent(String.self, forKey: .createdAt),
                  let isoDate = ISO8601DateFormatter().date(from: str) {
            self.createdAt = isoDate
        } else {
            self.createdAt = Date()
        }
    }

    public var date: Date? {
        DateUtils.isoDateFormatter.date(from: dateString)
    }

    public var formattedDate: String {
        guard let d = date else { return dateString }
        return DateUtils.formatDisplayDate(d)
    }
}

public enum AttendanceStatus: String, Codable, CaseIterable {
    case none
    case attended
    case skipped
}

public enum TransferType: String, Codable {
    case removal
    case addition
    case roomChange
}

public struct TransferItem: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var linkId: Int64
    public var type: TransferType
    public var teacher: String
    public var subject: String
    public var group: String
    
    public var removalDate: Date?
    public var removalLesson: Int?
    
    public var additionDate: Date?
    public var additionLesson: Int?
    public var newRoom: String?
    public var substituteTeacher: String?
    
    public init(
        id: UUID = UUID(),
        linkId: Int64 = 0,
        type: TransferType,
        teacher: String,
        subject: String,
        group: String,
        removalDate: Date? = nil,
        removalLesson: Int? = nil,
        additionDate: Date? = nil,
        additionLesson: Int? = nil,
        newRoom: String? = nil,
        substituteTeacher: String? = nil
    ) {
        self.id = id
        self.linkId = linkId
        self.type = type
        self.teacher = teacher
        self.subject = subject
        self.group = group
        self.removalDate = removalDate
        self.removalLesson = removalLesson
        self.additionDate = additionDate
        self.additionLesson = additionLesson
        self.newRoom = newRoom
        self.substituteTeacher = substituteTeacher
    }
    
    public func matchesGroup(_ groupName: String) -> Bool {
        let g = group.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let target = groupName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return g.contains(target) || target.contains(g)
    }
    
    public func matchesTeacher(_ teacherName: String) -> Bool {
        let t = teacher.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let target = teacherName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t.contains(target) || target.contains(t)
    }
}

public enum SelectionType: String, Codable, CaseIterable {
    case group = "group"
    case teacher = "teacher"
    
    public var title: String {
        switch self {
        case .group: return "Группа"
        case .teacher: return "Преподаватель"
        }
    }
}

public struct GroupOrTeacher: Identifiable, Codable, Equatable, Hashable {
    public var id: String { "\(type.rawValue)_\(name)" }
    public var name: String
    public var type: SelectionType
    public var isFavorite: Bool
    
    public init(name: String, type: SelectionType, isFavorite: Bool = false) {
        self.name = name
        self.type = type
        self.isFavorite = isFavorite
    }
}

public struct Holiday: Identifiable, Codable, Equatable {
    public var id: String { "\(year ?? 0)_\(month)_\(day)" }
    public var month: Int
    public var day: Int
    public var name: String
    public var year: Int?
    
    public init(month: Int, day: Int, name: String, year: Int? = nil) {
        self.month = month
        self.day = day
        self.name = name
        self.year = year
    }
}

public struct NextLesson: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var subjectName: String
    public var lessonType: String
    public var room: String
    public var teacherOrGroup: String
    public var date: Date
    public var lessonNumber: Int
    public var timeStart: String
    public var timeEnd: String
    
    public init(
        id: UUID = UUID(),
        subjectName: String,
        lessonType: String,
        room: String,
        teacherOrGroup: String,
        date: Date,
        lessonNumber: Int,
        timeStart: String,
        timeEnd: String
    ) {
        self.id = id
        self.subjectName = subjectName
        self.lessonType = lessonType
        self.room = room
        self.teacherOrGroup = teacherOrGroup
        self.date = date
        self.lessonNumber = lessonNumber
        self.timeStart = timeStart
        self.timeEnd = timeEnd
    }
}

public struct ScheduleClockState: Equatable {
    public var currentLessonNumber: Int?
    public var nextLessonNumber: Int?
    public var minutesLeftInCurrent: Int
    public var currentProgressPercent: Double // 0.0 ... 1.0
    public var minutesUntilNext: Int
    public var isBreak: Bool
    public var currentStage: Int // 1=first 45m, 2=5m break, 3=second 45m
    public var stageStatusText: String
    
    public init(
        currentLessonNumber: Int? = nil,
        nextLessonNumber: Int? = nil,
        minutesLeftInCurrent: Int = -1,
        currentProgressPercent: Double = 0.0,
        minutesUntilNext: Int = -1,
        isBreak: Bool = false,
        currentStage: Int = 1,
        stageStatusText: String = ""
    ) {
        self.currentLessonNumber = currentLessonNumber
        self.nextLessonNumber = nextLessonNumber
        self.minutesLeftInCurrent = minutesLeftInCurrent
        self.currentProgressPercent = currentProgressPercent
        self.minutesUntilNext = minutesUntilNext
        self.isBreak = isBreak
        self.currentStage = currentStage
        self.stageStatusText = stageStatusText
    }
}

public struct LessonGap: Identifiable, Hashable {
    public var id: String
    public var afterLessonNumber: Int
    public var beforeLessonNumber: Int
    public var startTime: String
    public var endTime: String
    public var durationMinutes: Int
    public var formattedDuration: String
    
    public init(
        id: String? = nil,
        afterLessonNumber: Int,
        beforeLessonNumber: Int,
        startTime: String,
        endTime: String,
        durationMinutes: Int,
        formattedDuration: String
    ) {
        self.id = id ?? "gap_\(afterLessonNumber)_\(beforeLessonNumber)_\(startTime)"
        self.afterLessonNumber = afterLessonNumber
        self.beforeLessonNumber = beforeLessonNumber
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.formattedDuration = formattedDuration
    }
}

public enum DayScheduleEntry: Identifiable, Hashable {
    case lesson(ScheduleItem)
    case gap(LessonGap)
    
    public var id: String {
        switch self {
        case .lesson(let item):
            return "lesson_\(item.id.uuidString)"
        case .gap(let gap):
            return "gap_\(gap.id)"
        }
    }
}

// MARK: - Two-Group Schedule Comparison

public enum CompareSlotKind: String, Codable, Equatable, Hashable {
    case commonWindow
    case bothBusy
    case oneBusy
}

public struct CompareSlotEntry: Identifiable, Equatable, Hashable {
    public var id: Int { lessonNumber }
    public let lessonNumber: Int
    public let timeLabel: String
    public let kind: CompareSlotKind
    public let group1Text: String?
    public let group2Text: String?

    public init(
        lessonNumber: Int,
        timeLabel: String,
        kind: CompareSlotKind,
        group1Text: String?,
        group2Text: String?
    ) {
        self.lessonNumber = lessonNumber
        self.timeLabel = timeLabel
        self.kind = kind
        self.group1Text = group1Text
        self.group2Text = group2Text
    }
}

public struct CompareResult: Equatable {
    public let group1: String
    public let group2: String
    public let semester: SemesterType
    public let weekNumber: Int
    public let dayOfWeek: Int
    public let slots: [CompareSlotEntry]
    public let commonWindowsCount: Int
    public let bothBusyCount: Int
    public let oneBusyCount: Int

    public init(
        group1: String,
        group2: String,
        semester: SemesterType,
        weekNumber: Int,
        dayOfWeek: Int,
        slots: [CompareSlotEntry],
        commonWindowsCount: Int,
        bothBusyCount: Int,
        oneBusyCount: Int
    ) {
        self.group1 = group1
        self.group2 = group2
        self.semester = semester
        self.weekNumber = weekNumber
        self.dayOfWeek = dayOfWeek
        self.slots = slots
        self.commonWindowsCount = commonWindowsCount
        self.bothBusyCount = bothBusyCount
        self.oneBusyCount = oneBusyCount
    }

    public var summaryText: String {
        let dayShort = (dayOfWeek >= 1 && dayOfWeek <= Constants.dayNamesShort.count)
            ? Constants.dayNamesShort[dayOfWeek - 1]
            : ""
        return "\(dayShort) · общих окон: \(commonWindowsCount) · заняты оба: \(bothBusyCount) · одна группа: \(oneBusyCount)"
    }
}
