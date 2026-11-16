import Foundation

public struct ScheduleItem: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID = UUID()
    public var weekType: String        // "odd" or "even"
    public var dayOfWeek: Int          // 1..6 (1=ПН, 6=СБ)
    public var lessonNumber: Int       // 1..7
    public var groupName: String
    public var teacherName: String
    public var subjectName: String
    public var lessonType: String      // "Л", "П", "ЛР", "оЛ", "оП", "Экзамен"
    public var room: String
    public var weekSpec: String        // e.g. "1-16", "2,4,6" or empty
    public var source: String          // "group" or "teacher"
    
    // Status flags
    public var isCancelled: Bool = false
    public var isMovedIn: Bool = false
    public var isRoomChanged: Bool = false
    public var transferNote: String? = nil
    public var isExcluded: Bool = false // "Перезачёт"
    public var isSkipped: Bool = false  // "Н-ка"
    public var isAttended: Bool = false // "Посещено / Пойду"
    public var isCustom: Bool = false
    public var customEventId: UUID? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case weekType
        case dayOfWeek
        case lessonNumber
        case groupName
        case teacherName
        case subjectName
        case lessonType
        case room
        case weekSpec
        case source
        case isCancelled
        case isMovedIn
        case isRoomChanged
        case transferNote
        case isExcluded
        case isSkipped
        case isAttended
        case isCustom
        case customEventId
    }
    
    public var attendanceStatus: AttendanceStatus {
        if isSkipped { return .skipped }
        if isAttended { return .attended }
        return .none
    }
    
    public init(
        id: UUID = UUID(),
        weekType: String,
        dayOfWeek: Int,
        lessonNumber: Int,
        groupName: String,
        teacherName: String,
        subjectName: String,
        lessonType: String,
        room: String,
        weekSpec: String = "",
        source: String = "group",
        isCancelled: Bool = false,
        isMovedIn: Bool = false,
        isRoomChanged: Bool = false,
        transferNote: String? = nil,
        isExcluded: Bool = false,
        isSkipped: Bool = false,
        isAttended: Bool = false,
        isCustom: Bool = false,
        customEventId: UUID? = nil
    ) {
        self.id = id
        self.weekType = weekType
        self.dayOfWeek = dayOfWeek
        self.lessonNumber = lessonNumber
        self.groupName = groupName
        self.teacherName = teacherName
        self.subjectName = subjectName
        self.lessonType = lessonType
        self.room = room
        self.weekSpec = weekSpec
        self.source = source
        self.isCancelled = isCancelled
        self.isMovedIn = isMovedIn
        self.isRoomChanged = isRoomChanged
        self.transferNote = transferNote
        self.isExcluded = isExcluded
        self.isSkipped = isSkipped
        self.isAttended = isAttended
        self.isCustom = isCustom
        self.customEventId = customEventId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.weekType = try c.decode(String.self, forKey: .weekType)
        self.dayOfWeek = try c.decode(Int.self, forKey: .dayOfWeek)
        self.lessonNumber = try c.decode(Int.self, forKey: .lessonNumber)
        self.groupName = try c.decodeIfPresent(String.self, forKey: .groupName) ?? ""
        self.teacherName = try c.decodeIfPresent(String.self, forKey: .teacherName) ?? ""
        self.subjectName = try c.decode(String.self, forKey: .subjectName)
        self.lessonType = try c.decodeIfPresent(String.self, forKey: .lessonType) ?? ""
        self.room = try c.decodeIfPresent(String.self, forKey: .room) ?? ""
        self.weekSpec = try c.decodeIfPresent(String.self, forKey: .weekSpec) ?? ""
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? "group"
        self.isCancelled = try c.decodeIfPresent(Bool.self, forKey: .isCancelled) ?? false
        self.isMovedIn = try c.decodeIfPresent(Bool.self, forKey: .isMovedIn) ?? false
        self.isRoomChanged = try c.decodeIfPresent(Bool.self, forKey: .isRoomChanged) ?? false
        self.transferNote = try c.decodeIfPresent(String.self, forKey: .transferNote)
        self.isExcluded = try c.decodeIfPresent(Bool.self, forKey: .isExcluded) ?? false
        self.isSkipped = try c.decodeIfPresent(Bool.self, forKey: .isSkipped) ?? false
        self.isAttended = try c.decodeIfPresent(Bool.self, forKey: .isAttended) ?? false
        self.isCustom = try c.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        self.customEventId = try c.decodeIfPresent(UUID.self, forKey: .customEventId)
    }
    
    public var isOnline: Bool {
        lessonType.starts(with: "о")
    }
    
    public var isTransferred: Bool {
        isMovedIn || isRoomChanged || (transferNote != nil && !transferNote!.isEmpty)
    }
    
    public var timeLabel: String {
        Constants.getLessonTimeLabel(dayOfWeek: dayOfWeek, lessonNumber: lessonNumber)
    }
    
    public func isActiveOnWeek(_ week: Int) -> Bool {
        let trimmed = weekSpec.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let clean = trimmed.replacingOccurrences(of: " ", with: "")
        let parts = clean.split(separator: ",")
        for part in parts {
            if part.isEmpty { continue }
            if part.contains("-") {
                let range = part.split(separator: "-")
                if range.count == 2,
                   let start = Int(range[0]),
                   let end = Int(range[1]) {
                    if week >= start && week <= end { return true }
                }
            } else if let num = Int(part) {
                if num == week { return true }
            }
        }
        return false
    }
}
