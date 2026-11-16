import Foundation

public enum SemesterType: String, Codable, CaseIterable, Identifiable {
    case fall = "fall"
    case spring = "spring"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fall: return "Осенний семестр"
        case .spring: return "Весенний семестр"
        }
    }

    public var shortName: String {
        switch self {
        case .fall: return "Осень"
        case .spring: return "Весна"
        }
    }

    public var toastEmoji: String {
        switch self {
        case .fall: return "🍂"
        case .spring: return "🌸"
        }
    }

    public var other: SemesterType {
        self == .fall ? .spring : .fall
    }
}

public final class SemesterManager {
    public static let totalWeeks = 18

    private init() {}

    /// Календарное окно семестра:
    /// - spring: 30 января – 24 августа включительно
    /// - fall:   25 августа – 29 января включительно
    public static func getCurrentWindowSemester(today: Date = Date()) -> SemesterType {
        let cal = Calendar.current
        let month = cal.component(.month, from: today)
        let day = cal.component(.day, from: today)

        if (month == 1 && day >= 30) || (month >= 2 && month <= 7) || (month == 8 && day < 25) {
            return .spring
        }
        return .fall
    }

    /// Понедельник стартовой недели для указанного семестра, нормализованный через `DateUtils.mondayOfWeek(for:)`.
    public static func getDefaultStart(for semester: SemesterType, refDate: Date = Date()) -> Date {
        let cal = Calendar.current
        let year = cal.component(.year, from: refDate)
        let month = cal.component(.month, from: refDate)

        var comp = DateComponents()
        switch semester {
        case .spring:
            comp.year = (month >= 8) ? year + 1 : year
            comp.month = 2
            comp.day = 1
        case .fall:
            comp.year = (month < 8) ? year - 1 : year
            comp.month = 9
            comp.day = 1
        }
        let base = cal.date(from: comp) ?? refDate
        return DateUtils.mondayOfWeek(for: base)
    }

    public static func loadActiveSemester(userDefaults: UserDefaults = .standard) -> SemesterType {
        if let raw = userDefaults.string(forKey: Constants.prefActiveSemester),
           let sem = SemesterType(rawValue: raw) {
            return sem
        }
        return getCurrentWindowSemester()
    }

    public static func saveActiveSemester(_ semester: SemesterType, userDefaults: UserDefaults = .standard) {
        userDefaults.set(semester.rawValue, forKey: Constants.prefActiveSemester)
        let start = loadSemesterStart(for: semester, userDefaults: userDefaults)
        userDefaults.set(DateUtils.isoDateFormatter.string(from: start), forKey: Constants.prefSemesterStart)
    }

    public static func loadSemesterStart(for semester: SemesterType, userDefaults: UserDefaults = .standard) -> Date {
        let key = Constants.prefSemesterStartPrefix + semester.rawValue
        if let str = userDefaults.string(forKey: key),
           let d = DateUtils.isoDateFormatter.date(from: str) {
            return DateUtils.mondayOfWeek(for: d)
        }
        if let legacyStr = userDefaults.string(forKey: Constants.prefSemesterStart),
           let legacyDate = DateUtils.isoDateFormatter.date(from: legacyStr) {
            let month = Calendar.current.component(.month, from: legacyDate)
            let legacySem: SemesterType = (month >= 2 && month <= 7) ? .spring : .fall
            if legacySem == semester {
                let normalized = DateUtils.mondayOfWeek(for: legacyDate)
                userDefaults.set(DateUtils.isoDateFormatter.string(from: normalized), forKey: key)
                return normalized
            }
        }
        return getDefaultStart(for: semester)
    }

    public static func saveSemesterStart(_ date: Date, for semester: SemesterType, userDefaults: UserDefaults = .standard) {
        let normalized = DateUtils.mondayOfWeek(for: date)
        let iso = DateUtils.isoDateFormatter.string(from: normalized)
        userDefaults.set(iso, forKey: Constants.prefSemesterStartPrefix + semester.rawValue)
        if semester == loadActiveSemester(userDefaults: userDefaults) {
            userDefaults.set(iso, forKey: Constants.prefSemesterStart)
        }
    }

    public static func describeSemester(_ semester: SemesterType, startDate: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: startDate)
        let month = calendar.component(.month, from: startDate)
        let academicYear = (month >= 8) ? "\(year)/\(year + 1)" : "\(year - 1)/\(year)"
        return "\(semester.displayName) \(academicYear) уч.г., начался \(DateUtils.formatDisplayDate(startDate))"
    }

    // MARK: - Backward-Compatible Helpers

    public static func getDefaultSemesterStart(for date: Date = Date()) -> Date {
        let sem = getCurrentWindowSemester(today: date)
        return getDefaultStart(for: sem, refDate: date)
    }

    public static func loadSemesterStart() -> Date {
        loadSemesterStart(for: loadActiveSemester())
    }

    public static func describeSemester(startDate: Date) -> String {
        let month = Calendar.current.component(.month, from: startDate)
        let sem: SemesterType = (month >= 2 && month <= 7) ? .spring : .fall
        return describeSemester(sem, startDate: startDate)
    }
}

public final class WeekCalculator {
    public let semesterStartDate: Date

    public init(semesterStartDate: Date = SemesterManager.loadSemesterStart()) {
        self.semesterStartDate = DateUtils.mondayOfWeek(for: semesterStartDate)
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
        let baseMonday = DateUtils.mondayOfWeek(for: semesterStartDate)
        return Calendar.current.date(byAdding: .weekOfYear, value: weekNumber - 1, to: baseMonday)
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
