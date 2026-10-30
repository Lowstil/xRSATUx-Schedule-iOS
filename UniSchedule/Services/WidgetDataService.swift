import Foundation

public struct WidgetLessonData: Codable {
    public var lessonNumber: Int
    public var timeLabel: String
    public var subjectName: String
    public var room: String
    public var lessonType: String
    public var teacherOrGroup: String
}

public struct WidgetSchedulePayload: Codable {
    public var targetName: String
    public var isGroup: Bool
    public var dateString: String
    public var isDayOff: Bool
    public var holidayName: String?
    public var lessons: [WidgetLessonData]
}

public final class WidgetDataService {
    public static let shared = WidgetDataService()
    
    private init() {}
    
    public func exportForWidget(payload: WidgetSchedulePayload) {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier) ?? UserDefaults.standard
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: "today_widget_schedule")
        }
    }
}
