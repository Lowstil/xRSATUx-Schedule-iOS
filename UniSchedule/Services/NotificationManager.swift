import Foundation
import UserNotifications

public final class NotificationManager {
    public static let shared = NotificationManager()
    
    private init() {}
    
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            print("Notification auth error: \(error.localizedDescription)")
            return false
        }
    }
    
    public func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Lesson Reminder
    public func scheduleLessonReminder(
        lesson: NextLesson,
        minutesBefore: Int = 15
    ) {
        guard minutesBefore > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Скоро пара: \(lesson.subjectName)"
        content.body = "Начало в \(lesson.timeStart) · Аудитория: \(lesson.room) (\(lesson.lessonType))"
        content.sound = .default
        
        // Parse time start into DateComponents
        let timeParts = lesson.timeStart.split(separator: ":")
        guard timeParts.count == 2,
              let hour = Int(timeParts[0]),
              let min = Int(timeParts[1]) else { return }
        
        var calendar = Calendar.current
        var lessonDateComponents = calendar.dateComponents([.year, .month, .day], from: lesson.date)
        lessonDateComponents.hour = hour
        lessonDateComponents.minute = min
        
        guard let lessonStart = calendar.date(from: lessonDateComponents),
              let triggerDate = calendar.date(byAdding: .minute, value: -minutesBefore, to: lessonStart) else {
            return
        }
        
        // Ensure trigger date is in the future
        guard triggerDate > Date() else { return }
        
        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let identifier = "lesson_reminder_\(lesson.date)_\(lesson.lessonNumber)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Morning Digest (07:30)
    public func scheduleMorningDigest(firstLessonTime: String, totalLessonsCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🎓 Расписание на сегодня"
        if totalLessonsCount > 0 {
            content.body = "Сегодня запланировано пар: \(totalLessonsCount). Первая пара начнётся в \(firstLessonTime)."
        } else {
            content.body = "Сегодня пар нет! Отличного дня."
        }
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 7
        dateComponents.minute = 30
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "morning_digest", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}
