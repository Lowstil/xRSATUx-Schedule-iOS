import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public struct WidgetLessonData: Codable, Equatable {
    public var lessonNumber: Int
    public var timeLabel: String
    public var subjectName: String
    public var room: String
    public var lessonType: String
    public var teacherOrGroup: String

    public init(
        lessonNumber: Int,
        timeLabel: String,
        subjectName: String,
        room: String,
        lessonType: String,
        teacherOrGroup: String
    ) {
        self.lessonNumber = lessonNumber
        self.timeLabel = timeLabel
        self.subjectName = subjectName
        self.room = room
        self.lessonType = lessonType
        self.teacherOrGroup = teacherOrGroup
    }
}

public struct WidgetSchedulePayload: Codable, Equatable {
    public var targetName: String
    public var isGroup: Bool
    public var dateString: String
    public var isDayOff: Bool
    public var holidayName: String?
    public var lessons: [WidgetLessonData]
    public var isPreview: Bool = false
    public var previewLabel: String? = nil
    public var semesterId: String = "fall"

    enum CodingKeys: String, CodingKey {
        case targetName
        case isGroup
        case dateString
        case isDayOff
        case holidayName
        case lessons
        case isPreview
        case previewLabel
        case semesterId
    }

    public init(
        targetName: String,
        isGroup: Bool,
        dateString: String,
        isDayOff: Bool,
        holidayName: String?,
        lessons: [WidgetLessonData],
        isPreview: Bool = false,
        previewLabel: String? = nil,
        semesterId: String = "fall"
    ) {
        self.targetName = targetName
        self.isGroup = isGroup
        self.dateString = dateString
        self.isDayOff = isDayOff
        self.holidayName = holidayName
        self.lessons = lessons
        self.isPreview = isPreview
        self.previewLabel = previewLabel
        self.semesterId = semesterId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.targetName = try c.decode(String.self, forKey: .targetName)
        self.isGroup = try c.decode(Bool.self, forKey: .isGroup)
        self.dateString = try c.decode(String.self, forKey: .dateString)
        self.isDayOff = try c.decode(Bool.self, forKey: .isDayOff)
        self.holidayName = try c.decodeIfPresent(String.self, forKey: .holidayName)
        self.lessons = try c.decodeIfPresent([WidgetLessonData].self, forKey: .lessons) ?? []
        self.isPreview = try c.decodeIfPresent(Bool.self, forKey: .isPreview) ?? false
        self.previewLabel = try c.decodeIfPresent(String.self, forKey: .previewLabel)
        self.semesterId = try c.decodeIfPresent(String.self, forKey: .semesterId) ?? "fall"
    }
}

public final class WidgetDataService {
    public static let shared = WidgetDataService()

    private init() {}

    public func exportForWidget(payload: WidgetSchedulePayload) {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier) ?? UserDefaults.standard
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: "today_widget_schedule")
        }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
