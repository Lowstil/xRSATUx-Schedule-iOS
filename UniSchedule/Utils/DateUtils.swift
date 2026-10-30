import Foundation

public final class DateUtils {
    public static let shared = DateUtils()
    private init() {}
    
    private static let localeRu = Locale(identifier: "ru_RU")
    
    public static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    public static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.locale = localeRu
        return f
    }()
    
    public static let displayDateShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM"
        f.locale = localeRu
        return f
    }()
    
    public static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    public static var today: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    public static func toScheduleDayOfWeek(date: Date) -> Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // Calendar weekday: 1 = Sunday, 2 = Monday, ... 7 = Saturday
        // We want: 1 = Monday ... 6 = Saturday, 0 = Sunday
        switch weekday {
        case 1: return 0 // Sunday
        case 2: return 1 // Monday
        case 3: return 2 // Tuesday
        case 4: return 3 // Wednesday
        case 5: return 4 // Thursday
        case 6: return 5 // Friday
        case 7: return 6 // Saturday
        default: return 0
        }
    }
    
    public static func mondayOfWeek(for date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
    
    public static func dateForDayInWeek(monday: Date, dayOfWeek: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: dayOfWeek - 1, to: monday) ?? monday
    }
    
    public static func formatDisplayDate(_ date: Date) -> String {
        displayDateFormatter.string(from: date)
    }
    
    public static func formatDisplayDateShort(_ date: Date) -> String {
        displayDateShortFormatter.string(from: date)
    }
    
    public static func monthNameRu(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = localeRu
        formatter.dateFormat = "LLLL"
        let name = formatter.string(from: date)
        return name.prefix(1).capitalized + name.dropFirst()
    }
    
    public static func formatMonthRangeRu(start: Date, end: Date) -> String {
        let cal = Calendar.current
        let m1 = cal.component(.month, from: start)
        let m2 = cal.component(.month, from: end)
        if m1 == m2 {
            return monthNameRu(for: start)
        } else {
            return "\(monthNameRu(for: start)) – \(monthNameRu(for: end))"
        }
    }
    
    public static func relativeDayLabel(for date: Date, today: Date = DateUtils.today) -> String? {
        let cal = Calendar.current
        let d1 = cal.startOfDay(for: today)
        let d2 = cal.startOfDay(for: date)
        let diff = cal.dateComponents([.day], from: d1, to: d2).day ?? 0
        
        if diff == 0 { return "Сегодня" }
        if diff == 1 { return "Завтра" }
        if diff > 1 {
            return "Наступит через \(diff) \(pluralDays(diff))"
        }
        return nil
    }
    
    public static func pluralDays(_ n: Int) -> String {
        let rem100 = n % 100
        let rem10 = n % 10
        if rem100 >= 11 && rem100 <= 14 { return "дней" }
        if rem10 == 1 { return "день" }
        if rem10 >= 2 && rem10 <= 4 { return "дня" }
        return "дней"
    }
}
