import Foundation
import UserNotifications

public final class NotificationManager {
    public static let shared = NotificationManager()
    private let liveLessonPrefix = "live_lesson_"
    
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
        
        let isoDate = DateUtils.isoDateFormatter.string(from: lesson.date)
        let identifier = "lesson_reminder_\(isoDate)_\(lesson.lessonNumber)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Morning Digest (07:30)
    public func scheduleMorningDigest(lessons: [ScheduleItem], date: Date = Date()) {
        let active = lessons
            .filter { !$0.isCancelled && !$0.isExcluded && !$0.isSkipped }
            .sorted { $0.lessonNumber < $1.lessonNumber }
        let dow = DateUtils.toScheduleDayOfWeek(date: date)
        let bellTimes = (dow >= 1 && dow <= 6) ? Constants.getLessonTimes(dayOfWeek: dow) : Constants.timesWeekday

        let firstTime: String
        if let first = active.first,
           first.lessonNumber >= 1,
           first.lessonNumber <= bellTimes.count {
            firstTime = bellTimes[first.lessonNumber - 1].start
        } else {
            firstTime = ""
        }
        scheduleMorningDigest(firstLessonTime: firstTime, totalLessonsCount: active.count)
    }

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
    
    // MARK: - Live Lesson Stage Notifications (45-5-45)
    public func cancelLiveLessonNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(self.liveLessonPrefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
        center.getDeliveredNotifications { notifications in
            let ids = notifications.map { $0.request.identifier }.filter { $0.hasPrefix(self.liveLessonPrefix) }
            if !ids.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
    }
    
    public func updateLiveLessonNotifications(lessons: [ScheduleItem], date: Date, enabled: Bool) {
        let activeLessons = lessons
            .filter { !$0.isCancelled && !$0.isExcluded && !$0.isSkipped }
            .sorted { $0.lessonNumber < $1.lessonNumber }
        
        let calendar = Calendar.current
        guard enabled, !activeLessons.isEmpty, calendar.isDateInToday(date) else {
            cancelLiveLessonNotifications()
            return
        }
        
        let dow = DateUtils.toScheduleDayOfWeek(date: date)
        guard dow >= 1 && dow <= 6 else {
            cancelLiveLessonNotifications()
            return
        }
        
        let bellTimes = Constants.getLessonTimes(dayOfWeek: dow)
        let now = Date()
        let dateStr = DateUtils.isoDateFormatter.string(from: date)
        let baseComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        // Only schedule/keep live alerts when an active lesson is currently in progress (start <= now <= end).
        var currentActive: (item: ScheduleItem, start: Date, end: Date)? = nil
        for item in activeLessons {
            guard item.lessonNumber >= 1 && item.lessonNumber <= bellTimes.count else { continue }
            let pair = bellTimes[item.lessonNumber - 1]
            guard let startParts = parseTime(pair.start),
                  let endParts = parseTime(pair.end) else {
                continue
            }
            var startComp = baseComponents
            startComp.hour = startParts.hour
            startComp.minute = startParts.minute
            
            var endComp = baseComponents
            endComp.hour = endParts.hour
            endComp.minute = endParts.minute
            
            guard let lessonStart = calendar.date(from: startComp),
                  let lessonEnd = calendar.date(from: endComp) else {
                continue
            }
            
            if lessonStart <= now && now <= lessonEnd {
                currentActive = (item, lessonStart, lessonEnd)
                break
            }
        }
        
        guard let active = currentActive else {
            cancelLiveLessonNotifications()
            return
        }
        
        let item = active.item
        let lessonStart = active.start
        let lessonEnd = active.end
        let roomLabel = item.room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Без аудитории"
            : "Ауд. \(item.room)"
        
        var pendingRequests: [UNNotificationRequest] = []
        
        // Stage 2 & 3 for standard 95-minute pairs (45m + 5m break + 45m)
        if lessonEnd.timeIntervalSince(lessonStart) >= 50 * 60 {
            if let breakDate = calendar.date(byAdding: .minute, value: 45, to: lessonStart),
               breakDate > now {
                let content = UNMutableNotificationContent()
                content.title = "Перерыв 5 мин · \(item.subjectName)"
                content.body = "Перерыв в \(item.lessonNumber)-й паре · до 2-й половины 5 мин"
                content.sound = .default
                pendingRequests.append(
                    makeLiveRequest(
                        id: "\(liveLessonPrefix)\(dateStr)_\(item.lessonNumber)_break",
                        triggerDate: breakDate,
                        content: content,
                        calendar: calendar
                    )
                )
            }
            
            if let secondHalfDate = calendar.date(byAdding: .minute, value: 50, to: lessonStart),
               secondHalfDate > now {
                let content = UNMutableNotificationContent()
                content.title = "2-я половина \(item.lessonNumber)-й пары: \(item.subjectName)"
                let typePart = item.lessonType.isEmpty ? "" : " (\(item.lessonType))"
                content.body = "Осталось 45 мин · \(roomLabel)\(typePart)"
                content.sound = .default
                pendingRequests.append(
                    makeLiveRequest(
                        id: "\(liveLessonPrefix)\(dateStr)_\(item.lessonNumber)_half2",
                        triggerDate: secondHalfDate,
                        content: content,
                        calendar: calendar
                    )
                )
            }
        }
        
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { existing in
            let oldIds = existing.map(\.identifier).filter { $0.hasPrefix(self.liveLessonPrefix) }
            if !oldIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: oldIds)
            }
            for request in pendingRequests {
                center.add(request)
            }
        }
    }
    
    private func parseTime(_ timeStr: String) -> (hour: Int, minute: Int)? {
        let parts = timeStr.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return nil }
        return (h, m)
    }
    
    private func makeLiveRequest(
        id: String,
        triggerDate: Date,
        content: UNMutableNotificationContent,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }
}
