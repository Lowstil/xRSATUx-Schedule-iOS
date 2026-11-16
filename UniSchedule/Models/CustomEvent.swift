import Foundation

public enum CustomEventWeekFilter: String, Codable, CaseIterable, Identifiable {
    case both = "both"
    case odd = "odd"
    case even = "even"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .both: return "Каждая"
        case .odd: return "Нечётная"
        case .even: return "Чётная"
        }
    }
}

public struct CustomEvent: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID = UUID()
    public var targetName: String
    public var isGroup: Bool
    public var dateIso: String?
    public var dayOfWeek: Int
    public var weekType: String
    public var lessonNumber: Int
    public var subjectName: String
    public var teacherName: String
    public var room: String
    public var note: String

    public init(
        id: UUID = UUID(),
        targetName: String,
        isGroup: Bool = true,
        dateIso: String? = nil,
        dayOfWeek: Int = 1,
        weekType: String = CustomEventWeekFilter.both.rawValue,
        lessonNumber: Int = 1,
        subjectName: String,
        teacherName: String = "",
        room: String = "",
        note: String = ""
    ) {
        self.id = id
        self.targetName = targetName
        self.isGroup = isGroup
        self.dateIso = dateIso
        self.dayOfWeek = dayOfWeek
        self.weekType = weekType
        self.lessonNumber = lessonNumber
        self.subjectName = subjectName
        self.teacherName = teacherName
        self.room = room
        self.note = note
    }

    public var isRecurring: Bool {
        let trimmed = (dateIso ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
    }

    public func matchesDate(_ date: Date, dayOfWeek: Int, weekType: String) -> Bool {
        if let iso = dateIso?.trimmingCharacters(in: .whitespacesAndNewlines), !iso.isEmpty {
            return iso == DateUtils.isoDateFormatter.string(from: date)
        }
        guard self.dayOfWeek == dayOfWeek else { return false }
        let filter = self.weekType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if filter.isEmpty || filter == CustomEventWeekFilter.both.rawValue {
            return true
        }
        return filter == weekType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public func toScheduleItem(dayOfWeek: Int, isGroup: Bool) -> ScheduleItem {
        let trimmedTeacher = teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTeacher = (!isGroup && trimmedTeacher.isEmpty) ? targetName : trimmedTeacher
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        return ScheduleItem(
            weekType: weekType,
            dayOfWeek: dayOfWeek,
            lessonNumber: lessonNumber,
            groupName: isGroup ? targetName : "",
            teacherName: resolvedTeacher,
            subjectName: subjectName,
            lessonType: "",
            room: room,
            weekSpec: "",
            source: "custom",
            transferNote: trimmedNote.isEmpty ? nil : trimmedNote,
            isCustom: true,
            customEventId: id
        )
    }
}
