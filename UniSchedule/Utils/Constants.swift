import Foundation
import SwiftUI

public enum Constants {
    // MARK: - URLs & Network
    public static let schedulePageURL = "https://www.rsatu.ru/students/raspisanie-zanyatiy/"
    public static let scheduleFilenameHint = "raspisanie"
    public static let scheduleFallbackURL = "https://www.rsatu.ru/upload/iblock/daf/p5jdqaiy99a16vhqmkyohmkjmoz8ppku/Raspisanie-zanyatiy-29.10.2026.xlsx"
    
    public static let transfersPageURL = "https://www.rsatu.ru/students/raspisanie-zanyatiy/"
    public static let transfersFilenameHint = "perenos"
    public static let transfersFallbackURL = "https://www.rsatu.ru/upload/iblock/5af/bn9ogs1h4fqoqca7ckkox1s8d24wnyiw/ZHurnal-perenosov-2026_2027-uch.g.xlsx"
    
    public static let scheduleCacheFileName = "schedule_cache.xlsx"
    public static let transfersCacheFileName = "transfers_cache.xlsx"
    public static let scheduleTTLHours = 12
    
    // MARK: - Lesson Types
    public static let lessonTypeLecture = "Л"
    public static let lessonTypePractice = "П"
    public static let lessonTypeLab = "ЛР"
    public static let lessonTypeOnlineLecture = "оЛ"
    public static let lessonTypeOnlinePractice = "оП"
    public static let lessonTypeExam = "Экзамен"
    
    // MARK: - Week Types
    public static let weekTypeOdd = "odd"
    public static let weekTypeEven = "even"
    
    // MARK: - Bells / Times
    public static let timesWeekday: [(start: String, end: String)] = [
        ("08:30", "10:05"),
        ("10:15", "11:50"),
        ("12:40", "14:15"), // Большая перемена 50 мин (11:50 - 12:40)
        ("14:25", "16:00"),
        ("16:10", "17:45"),
        ("18:00", "19:25"),
        ("19:35", "21:00")
    ]
    
    public static let timesWeekend: [(start: String, end: String)] = [
        ("08:30", "10:05"),
        ("10:15", "11:50"),
        ("12:00", "13:35"),
        ("13:45", "15:20"),
        ("15:30", "17:05"),
        ("17:15", "18:40"),
        ("18:50", "20:15")
    ]
    
    public static let dayNamesShort = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ"]
    public static let dayNamesFull = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
    
    public static func getLessonTimes(dayOfWeek: Int) -> [(start: String, end: String)] {
        return (dayOfWeek == 6) ? timesWeekend : timesWeekday
    }
    
    public static func getLessonTimeLabel(dayOfWeek: Int, lessonNumber: Int) -> String {
        let times = getLessonTimes(dayOfWeek: dayOfWeek)
        guard lessonNumber >= 1 && lessonNumber <= times.count else { return "" }
        let t = times[lessonNumber - 1]
        return "\(t.start)–\(t.end)"
    }
    
    // MARK: - UserDefaults Keys
    public static let prefSelectionType = "pref_selection_type"
    public static let prefSelectionName = "pref_selection_name"
    public static let prefSemesterStart = "pref_semester_start"
    public static let prefLastUpdated = "pref_last_updated"
    public static let prefThemeMode = "pref_theme_mode"
    public static let prefFavorites = "pref_favorites_list"
    public static let prefRemindersEnabled = "pref_reminders_enabled"
    public static let prefReminderMinutesBefore = "pref_reminder_minutes_before"
    public static let prefMorningDigestEnabled = "pref_morning_digest_enabled"
    public static let prefSkippedLessons = "pref_skipped_lessons"
    public static let prefExcludedSubjectsPrefix = "pref_excluded_subjects_"
    
    // MARK: - App Group for Widgets
    public static let appGroupIdentifier = "group.com.university.schedule"
}
