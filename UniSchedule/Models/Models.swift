import Foundation

public struct LessonNote: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var dateString: String // "yyyy-MM-dd"
    public var lessonNumber: Int
    public var subjectName: String
    public var noteText: String
    public var isCompleted: Bool
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        dateString: String,
        lessonNumber: Int,
        subjectName: String,
        noteText: String,
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.dateString = dateString
        self.lessonNumber = lessonNumber
        self.subjectName = subjectName
        self.noteText = noteText
        self.isCompleted = isCompleted
        self.createdAt = createdAt
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
