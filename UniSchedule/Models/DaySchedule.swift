import Foundation

public struct DaySchedule: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var dayOfWeek: Int // 1..6
    public var date: Date
    public var lessons: [ScheduleItem]
    public var isDayOff: Bool
    public var holidayName: String?
    
    public init(
        id: UUID = UUID(),
        dayOfWeek: Int,
        date: Date,
        lessons: [ScheduleItem] = [],
        isDayOff: Bool = false,
        holidayName: String? = nil
    ) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.date = date
        self.lessons = lessons
        self.isDayOff = isDayOff
        self.holidayName = holidayName
    }
    
    public var dayNameShort: String {
        guard dayOfWeek >= 1 && dayOfWeek <= Constants.dayNamesShort.count else { return "" }
        return Constants.dayNamesShort[dayOfWeek - 1]
    }
    
    public var dayNameFull: String {
        guard dayOfWeek >= 1 && dayOfWeek <= Constants.dayNamesFull.count else { return "" }
        return Constants.dayNamesFull[dayOfWeek - 1]
    }
    
    public var relativeLabel: String? {
        DateUtils.relativeDayLabel(for: date)
    }
}

public struct WeekSchedule: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var weekNumber: Int
    public var isEven: Bool
    public var days: [DaySchedule]
    
    public init(id: UUID = UUID(), weekNumber: Int, isEven: Bool, days: [DaySchedule] = []) {
        self.id = id
        self.weekNumber = weekNumber
        self.isEven = isEven
        self.days = days
    }
    
    public var weekTypeString: String {
        isEven ? Constants.weekTypeEven : Constants.weekTypeOdd
    }
    
    public var weekDescription: String {
        "Неделя \(weekNumber) (\(isEven ? "чётная" : "нечётная"))"
    }
}
