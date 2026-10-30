import Foundation

public final class SemesterManager {
    public static let totalWeeks = 18
    
    private init() {}
    
    /**
     * По правилам РГАТУ им. П. А. Соловьёва:
     * - Осенний семестр начинается 1 сентября.
     * - Весенний семестр начинается 1 февраля.
     *
     * Февраль–Август  -> весенний (1 февраля)
     * Сентябрь–Декабрь -> осенний (1 сентября текущего года)
     * Январь           -> осенний прошлого года (1 сентября прошлого года)
     */
    public static func getDefaultSemesterStart(for date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        
        var comp = DateComponents()
        if month >= 2 && month <= 8 {
            comp.year = year
            comp.month = 2
            comp.day = 1
        } else if month >= 9 {
            comp.year = year
            comp.month = 9
            comp.day = 1
        } else {
            comp.year = year - 1
            comp.month = 9
            comp.day = 1
        }
        return calendar.date(from: comp) ?? date
    }
    
    public static func loadSemesterStart() -> Date {
        if let str = UserDefaults.standard.string(forKey: Constants.prefSemesterStart),
           let d = DateUtils.isoDateFormatter.date(from: str) {
            return d
        }
        return getDefaultSemesterStart()
    }
    
    public static func describeSemester(startDate: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: startDate)
        let month = calendar.component(.month, from: startDate)
        
        let semesterName: String
        let academicYear: String
        if month >= 2 && month <= 8 {
            semesterName = "Весенний семестр"
            academicYear = "\(year)/\(year + 1)"
        } else if month >= 9 {
            semesterName = "Осенний семестр"
            academicYear = "\(year)/\(year + 1)"
        } else {
            semesterName = "Осенний семестр"
            academicYear = "\(year - 1)/\(year)"
        }
        return "\(semesterName) \(academicYear) уч.г., начался \(DateUtils.formatDisplayDate(startDate))"
    }
}

public final class WeekCalculator {
    public let semesterStartDate: Date
    
    public init(semesterStartDate: Date = SemesterManager.loadSemesterStart()) {
        self.semesterStartDate = semesterStartDate
    }
    
    /**
     * Номер учебной недели (1..18).
     * Если дата до начала семестра или после 18-й недели, возвращается -1.
     */
    public func getWeekNumber(for date: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: semesterStartDate)
        let target = calendar.startOfDay(for: date)
        
        if target < start { return -1 }
        
        // Days difference from semester start
        guard let days = calendar.dateComponents([.day], from: start, to: target).day else {
            return -1
        }
        
        let week = (days / 7) + 1
        return (week > SemesterManager.totalWeeks) ? -1 : week
    }
    
    public func isEvenWeek(_ weekNumber: Int) -> Bool {
        weekNumber > 0 && weekNumber % 2 == 0
    }
    
    public func isOddWeek(_ weekNumber: Int) -> Bool {
        weekNumber > 0 && weekNumber % 2 != 0
    }
    
    public func getWeekType(for date: Date) -> String? {
        let w = getWeekNumber(for: date)
        if w < 0 { return nil }
        return isEvenWeek(w) ? Constants.weekTypeEven : Constants.weekTypeOdd
    }
    
    public func getMondayOfWeek(weekNumber: Int) -> Date? {
        guard weekNumber >= 1 && weekNumber <= SemesterManager.totalWeeks else { return nil }
        return Calendar.current.date(byAdding: .weekOfYear, value: weekNumber - 1, to: semesterStartDate)
    }
    
    public func getSaturdayOfWeek(weekNumber: Int) -> Date? {
        guard let mon = getMondayOfWeek(weekNumber: weekNumber) else { return nil }
        return Calendar.current.date(byAdding: .day, value: 5, to: mon)
    }
    
    public var currentWeekNumber: Int {
        let w = getWeekNumber(for: Date())
        return (w > 0) ? w : 1
    }
    
    public var currentWeekType: String {
        getWeekType(for: Date()) ?? Constants.weekTypeOdd
    }
}
