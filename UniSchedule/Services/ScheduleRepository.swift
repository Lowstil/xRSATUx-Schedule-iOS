import Foundation
import Combine

public final class ScheduleRepository: ObservableObject {
    public static let shared = ScheduleRepository()
    
    @Published public private(set) var allItems: [ScheduleItem] = []
    @Published public private(set) var groups: [String] = []
    @Published public private(set) var teachers: [String] = []
    @Published public private(set) var favorites: [GroupOrTeacher] = []
    @Published public private(set) var notes: [LessonNote] = []
    @Published public private(set) var lastUpdated: Date? = nil
    @Published public private(set) var isUpdating: Bool = false
    
    private let userDefaults: UserDefaults
    private let scheduleFilter = ScheduleFilter()
    
    private let cacheFileName = "schedule_data.json"
    private var cacheFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(cacheFileName)
    }
    
    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadFromCacheOrBundle()
        loadFavorites()
        loadNotes()
    }
    
    // MARK: - Initial Load
    public func loadFromCacheOrBundle() {
        if FileManager.default.fileExists(atPath: cacheFileURL.path),
           let data = try? Data(contentsOf: cacheFileURL),
           let parsed = try? ScheduleParser.shared.parseScheduleJSON(data: data) {
            applyParsedData(parsed)
            return
        }
        
        // Fallback to bundled sample schedule
        if let sample = ScheduleParser.shared.loadBundledSampleSchedule() {
            applyParsedData(sample)
        }
    }
    
    private func applyParsedData(_ data: ParsedScheduleData) {
        self.allItems = data.items
        self.groups = data.groups.sorted()
        self.teachers = data.teachers.sorted()
        if let lu = ISO8601DateFormatter().date(from: data.lastUpdated) {
            self.lastUpdated = lu
        } else {
            self.lastUpdated = Date()
        }
    }
    
    // MARK: - Remote Refresh
    public func refreshSchedule() async throws {
        await MainActor.run { self.isUpdating = true }
        defer {
            Task { @MainActor in self.isUpdating = false }
        }
        
        let tempCache = FileManager.default.temporaryDirectory.appendingPathComponent(Constants.scheduleCacheFileName)
        try await NetworkService.shared.fetchScheduleFile(cacheURL: tempCache)
        
        // In full app with CoreXLSX or server sync, the file is parsed here
        // If download succeeds, we save to cacheFileURL and update state
        if let currentData = try? Data(contentsOf: cacheFileURL) {
            if let parsed = try? ScheduleParser.shared.parseScheduleJSON(data: currentData) {
                await MainActor.run {
                    self.applyParsedData(parsed)
                    self.lastUpdated = Date()
                }
            }
        }
    }
    
    // MARK: - Query Schedule
    public func getSchedule(for targetName: String, isGroup: Bool) -> [ScheduleItem] {
        let clean = targetName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return [] }
        
        let excluded = getExcludedSubjects(for: targetName)
        
        return allItems.filter { item in
            let match = isGroup
                ? item.groupName.lowercased() == clean
                : item.teacherName.lowercased().contains(clean)
            return match
        }.map { item in
            var copy = item
            if excluded.contains(item.subjectName) {
                copy.isExcluded = true
            }
            if self.isLessonSkipped(dateString: DateUtils.isoDateFormatter.string(from: Date()), lessonNumber: item.lessonNumber, subject: item.subjectName) {
                copy.isSkipped = true
            }
            return copy
        }
    }
    
    // MARK: - Next Upcoming Lesson
    public func findNextLesson(
        targetName: String,
        isGroup: Bool,
        weekCalculator: WeekCalculator,
        fromDate: Date = Date(),
        maxDaysAhead: Int = 14
    ) -> NextLesson? {
        let items = getSchedule(for: targetName, isGroup: isGroup)
        guard !items.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let timeFormatter = DateUtils.timeFormatter
        let nowTimeStr = timeFormatter.string(from: fromDate)
        
        for dayOffset in 0...maxDaysAhead {
            guard let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: fromDate) else { continue }
            if HolidayChecker.shared.isDayOff(date: checkDate) { continue }
            
            let dow = DateUtils.toScheduleDayOfWeek(date: checkDate)
            guard dow >= 1 && dow <= 6 else { continue }
            
            let weekNum = weekCalculator.getWeekNumber(for: checkDate)
            guard weekNum > 0 else { continue }
            let weekType = weekCalculator.isEvenWeek(weekNum) ? Constants.weekTypeEven : Constants.weekTypeOdd
            
            let dayLessons = items.filter { item in
                item.dayOfWeek == dow &&
                item.weekType.lowercased() == weekType.lowercased() &&
                item.isActiveOnWeek(weekNum) &&
                !item.isCancelled &&
                !item.isExcluded &&
                !item.isSkipped
            }.sorted(by: { $0.lessonNumber < $1.lessonNumber })
            
            let times = Constants.getLessonTimes(dayOfWeek: dow)
            
            for item in dayLessons {
                guard item.lessonNumber <= times.count else { continue }
                let timePair = times[item.lessonNumber - 1]
                
                // If today, only consider future lessons
                if dayOffset == 0 {
                    if timePair.start <= nowTimeStr { continue }
                }
                
                return NextLesson(
                    subjectName: item.subjectName,
                    lessonType: item.lessonType,
                    room: item.room,
                    teacherOrGroup: isGroup ? item.teacherName : item.groupName,
                    date: checkDate,
                    lessonNumber: item.lessonNumber,
                    timeStart: timePair.start,
                    timeEnd: timePair.end
                )
            }
        }
        return nil
    }
    
    // MARK: - Favorites
    public func loadFavorites() {
        if let data = userDefaults.data(forKey: Constants.prefFavorites),
           let list = try? JSONDecoder().decode([GroupOrTeacher].self, from: data) {
            self.favorites = list
        } else {
            // Default sample favorites
            self.favorites = [
                GroupOrTeacher(name: "ИВБ-24", type: .group, isFavorite: true),
                GroupOrTeacher(name: "ДТБ-23", type: .group, isFavorite: true),
                GroupOrTeacher(name: "Башкин М.А.", type: .teacher, isFavorite: true)
            ]
        }
    }
    
    public func isFavorite(name: String, type: SelectionType) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return favorites.contains { $0.name.lowercased() == clean && $0.type == type }
    }
    
    public func toggleFavorite(name: String, type: SelectionType) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = favorites.firstIndex(where: { $0.name.lowercased() == clean.lowercased() && $0.type == type }) {
            favorites.remove(at: idx)
        } else {
            favorites.append(GroupOrTeacher(name: clean, type: type, isFavorite: true))
        }
        if let data = try? JSONEncoder().encode(favorites) {
            userDefaults.set(data, forKey: Constants.prefFavorites)
        }
    }
    
    // MARK: - Notes (Homework / Tasks)
    public func loadNotes() {
        if let data = userDefaults.data(forKey: "lesson_notes_list"),
           let list = try? JSONDecoder().decode([LessonNote].self, from: data) {
            self.notes = list
        }
    }
    
    public func getNote(dateString: String, lessonNumber: Int, subject: String) -> LessonNote? {
        notes.first { $0.dateString == dateString && $0.lessonNumber == lessonNumber && $0.subjectName == subject }
    }
    
    public func saveNote(_ note: LessonNote) {
        if let idx = notes.firstIndex(where: { $0.dateString == note.dateString && $0.lessonNumber == note.lessonNumber && $0.subjectName == note.subjectName }) {
            notes[idx] = note
        } else {
            notes.append(note)
        }
        persistNotes()
    }
    
    public func toggleNoteCompleted(id: UUID) {
        if let idx = notes.firstIndex(where: { $0.id == id }) {
            notes[idx].isCompleted.toggle()
            persistNotes()
        }
    }
    
    public func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
        persistNotes()
    }
    
    private func persistNotes() {
        if let data = try? JSONEncoder().encode(notes) {
            userDefaults.set(data, forKey: "lesson_notes_list")
        }
    }
    
    // MARK: - Skipped Lessons ("Не пойду на пару")
    public func isLessonSkipped(dateString: String, lessonNumber: Int, subject: String) -> Bool {
        let set = Set(userDefaults.stringArray(forKey: Constants.prefSkippedLessons) ?? [])
        let key = "\(dateString)#\(lessonNumber)#\(subject)"
        return set.contains(key)
    }
    
    public func toggleLessonSkipped(dateString: String, lessonNumber: Int, subject: String) -> Bool {
        var set = Set(userDefaults.stringArray(forKey: Constants.prefSkippedLessons) ?? [])
        let key = "\(dateString)#\(lessonNumber)#\(subject)"
        let wasSkipped = set.contains(key)
        if wasSkipped {
            set.remove(key)
        } else {
            set.insert(key)
        }
        userDefaults.set(Array(set), forKey: Constants.prefSkippedLessons)
        return !wasSkipped
    }
    
    // MARK: - Excluded Subjects ("Перезачёт")
    public func getExcludedSubjects(for group: String) -> Set<String> {
        let key = Constants.prefExcludedSubjectsPrefix + group.trimmingCharacters(in: .whitespacesAndNewlines)
        return Set(userDefaults.stringArray(forKey: key) ?? [])
    }
    
    public func toggleExcludedSubject(group: String, subject: String) {
        let key = Constants.prefExcludedSubjectsPrefix + group.trimmingCharacters(in: .whitespacesAndNewlines)
        var set = getExcludedSubjects(for: group)
        if set.contains(subject) {
            set.remove(subject)
        } else {
            set.insert(subject)
        }
        userDefaults.set(Array(set), forKey: key)
    }
}
