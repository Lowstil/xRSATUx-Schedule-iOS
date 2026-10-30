import Foundation

public final class HolidayChecker {
    public static let shared = HolidayChecker()
    
    // Ежегодные нерабочие праздничные дни РФ (ст. 112 ТК РФ)
    private static let annualHolidays: [Holiday] = [
        Holiday(month: 1, day: 1, name: "Новогодние каникулы"),
        Holiday(month: 1, day: 2, name: "Новогодние каникулы"),
        Holiday(month: 1, day: 3, name: "Новогодние каникулы"),
        Holiday(month: 1, day: 4, name: "Новогодние каникулы"),
        Holiday(month: 1, day: 5, name: "Новогодние каникулы"),
        Holiday(month: 1, day: 6, name: "Новогодние каникулы"),
        Holiday(month: 1, day: 7, name: "Рождество Христово"),
        Holiday(month: 1, day: 8, name: "Новогодние каникулы"),
        Holiday(month: 2, day: 23, name: "День защитника Отечества"),
        Holiday(month: 3, day: 8, name: "Международный женский день"),
        Holiday(month: 5, day: 1, name: "Праздник Весны и Труда"),
        Holiday(month: 5, day: 9, name: "День Победы"),
        Holiday(month: 6, day: 12, name: "День России"),
        Holiday(month: 11, day: 4, name: "День народного единства")
    ]
    
    private var customHolidays: [Holiday] = []
    
    public init(customHolidays: [Holiday] = []) {
        self.customHolidays = customHolidays
    }
    
    public func isHoliday(date: Date) -> Bool {
        getHolidayName(date: date) != nil
    }
    
    /**
     * Внимание: по регламенту университета РГАТУ суббота — учебный день!
     * Выходным по календарю недели считается только воскресенье.
     */
    public func isWeekend(date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 // 1 is Sunday
    }
    
    public func isDayOff(date: Date) -> Bool {
        isWeekend(date: date) || isHoliday(date: date)
    }
    
    public func getHolidayName(date: Date) -> String? {
        let cal = Calendar.current
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        let y = cal.component(.year, from: date)
        
        for h in Self.annualHolidays {
            if h.month == m && h.day == d {
                return h.name
            }
        }
        
        for h in customHolidays {
            if h.month == m && h.day == d {
                if let hy = h.year {
                    if hy == y { return h.name }
                } else {
                    return h.name
                }
            }
        }
        
        return nil
    }
}
