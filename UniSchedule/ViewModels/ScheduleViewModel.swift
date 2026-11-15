import Foundation
import SwiftUI
import Combine

@MainActor
public final class ScheduleViewModel: ObservableObject {
    @Published public var selectedName: String = ""
    @Published public var isGroup: Bool = true
    @Published public var selectedWeekNumber: Int = 1
    @Published public var selectedDayOfWeek: Int = 1 {
        didSet {
            updateLiveClock()
        }
    }
    
    @Published public var weekSchedule: WeekSchedule? = nil
    @Published public var clockState: ScheduleClockState = ScheduleClockState()
    @Published public var nextUpcomingLesson: NextLesson? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var skipLimitPercent: Int
    @Published public var activeScheduleDiff: ScheduleDiffResult? = nil
    @Published public var showScheduleDiffSheet: Bool = false
    
    private let repository = ScheduleRepository.shared
    private let scheduleFilter = ScheduleFilter()
    public private(set) var weekCalculator: WeekCalculator
    private var cancellables = Set<AnyCancellable>()
    private var lastLiveNotifSyncKey: String? = nil
    
    public init() {
        let semesterStart = SemesterManager.loadSemesterStart()
        self.weekCalculator = WeekCalculator(semesterStartDate: semesterStart)
        self.skipLimitPercent = AttendanceManager.shared.skipLimitPercent
        self.activeScheduleDiff = repository.lastScheduleDiff
        
        // Restore user defaults
        let savedType = UserDefaults.standard.string(forKey: Constants.prefSelectionType) ?? "group"
        let savedName = UserDefaults.standard.string(forKey: Constants.prefSelectionName) ?? "ИВБ-24"
        self.isGroup = (savedType == "group")
        self.selectedName = savedName
        
        // Default to current week & day (auto-advances Sunday -> Monday)
        let targetDate = DateUtils.initialScheduleDate(Date()) ?? Date()
        let targetWeek = weekCalculator.getWeekNumber(for: targetDate)
        self.selectedWeekNumber = (targetWeek > 0) ? targetWeek : weekCalculator.currentWeekNumber
        
        let targetDow = DateUtils.toScheduleDayOfWeek(date: targetDate)
        self.selectedDayOfWeek = (targetDow >= 1 && targetDow <= 6) ? targetDow : 1
        
        loadSchedule()
        startLiveTimer()
        bindRepository()
    }
    
    private func bindRepository() {
        // Automatically reload UI whenever repository completes an update
        repository.$allItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadSchedule()
            }
            .store(in: &cancellables)
        
        repository.$lastScheduleDiff
            .receive(on: DispatchQueue.main)
            .sink { [weak self] diff in
                guard let self else { return }
                self.activeScheduleDiff = diff
                if let diff, !diff.isEmpty {
                    self.showScheduleDiffSheet = true
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("AttendanceChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadSchedule()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.lastLiveNotifSyncKey = nil
                self.syncLiveLessonNotifications()
            }
            .store(in: &cancellables)
    }
    
    public var weekDays: [DaySchedule] {
        weekSchedule?.days ?? []
    }
    
    public func entries(for day: DaySchedule) -> [DayScheduleEntry] {
        ScheduleFilter.buildDayScheduleEntries(for: day.lessons, dayOfWeek: day.dayOfWeek)
    }
    
    public var currentDaySchedule: DaySchedule? {
        guard let week = weekSchedule,
              let day = week.days.first(where: { $0.dayOfWeek == selectedDayOfWeek }) else {
            return nil
        }
        return day
    }
    
    public func selectTarget(name: String, isGroup: Bool) {
        self.selectedName = name
        self.isGroup = isGroup
        
        UserDefaults.standard.set(isGroup ? "group" : "teacher", forKey: Constants.prefSelectionType)
        UserDefaults.standard.set(name, forKey: Constants.prefSelectionName)
        
        loadSchedule()
    }
    
    public func loadSchedule() {
        guard !selectedName.isEmpty else { return }
        
        let allItems = repository.getSchedule(for: selectedName, isGroup: isGroup)
        let monday = weekCalculator.getMondayOfWeek(weekNumber: selectedWeekNumber) ?? DateUtils.mondayOfWeek(for: Date())
        let weekType = weekCalculator.isEvenWeek(selectedWeekNumber) ? Constants.weekTypeEven : Constants.weekTypeOdd
        
        self.weekSchedule = scheduleFilter.buildWeekSchedule(
            allItems: allItems,
            weekNumber: selectedWeekNumber,
            weekType: weekType,
            mondayOfWeek: monday,
            allTransfers: [],
            targetName: selectedName,
            isGroup: isGroup
        )
        
        lastLiveNotifSyncKey = nil
        updateClockAndNextLesson()
        exportWidgetData()
    }
    
    public func refresh() async {
        isLoading = true
        errorMessage = nil
        weekCalculator = WeekCalculator(semesterStartDate: SemesterManager.loadSemesterStart())
        do {
            try await repository.refreshSchedule()
            loadSchedule()
            HapticsService.shared.notification(.success)
        } catch {
            self.errorMessage = "Не удалось обновить: \(error.localizedDescription)"
            HapticsService.shared.notification(.error)
        }
        isLoading = false
    }
    
    // MARK: - Navigation Helpers
    public func previousWeek() {
        if selectedWeekNumber > 1 {
            selectedWeekNumber -= 1
            selectedDayOfWeek = 1
            loadSchedule()
            HapticsService.shared.selection()
        }
    }
    
    public func nextWeek() {
        if selectedWeekNumber < SemesterManager.totalWeeks {
            selectedWeekNumber += 1
            selectedDayOfWeek = 1
            loadSchedule()
            HapticsService.shared.selection()
        }
    }
    
    public func resetToCurrentWeekAndDay() {
        weekCalculator = WeekCalculator(semesterStartDate: SemesterManager.loadSemesterStart())
        let targetDate = DateUtils.initialScheduleDate(Date()) ?? Date()
        let targetWeek = weekCalculator.getWeekNumber(for: targetDate)
        self.selectedWeekNumber = (targetWeek > 0) ? targetWeek : weekCalculator.currentWeekNumber
        let dow = DateUtils.toScheduleDayOfWeek(date: targetDate)
        self.selectedDayOfWeek = (dow >= 1 && dow <= 6) ? dow : 1
        loadSchedule()
        HapticsService.shared.selection()
    }
    
    public func setSkipLimitPercent(_ pct: Int) {
        AttendanceManager.shared.skipLimitPercent = pct
        self.skipLimitPercent = AttendanceManager.shared.skipLimitPercent
        loadSchedule()
        HapticsService.shared.selection()
    }
    
    public func dismissScheduleDiff() {
        showScheduleDiffSheet = false
        repository.clearScheduleDiff()
        activeScheduleDiff = nil
    }
    
    public func selectDay(_ dow: Int) {
        guard dow >= 1 && dow <= 6 else { return }
        self.selectedDayOfWeek = dow
        HapticsService.shared.selection()
    }
    
    // MARK: - Actions on Lessons & Attendance
    public func toggleSkippedLesson(item: ScheduleItem) {
        guard let day = currentDaySchedule else { return }
        let dateStr = DateUtils.isoDateFormatter.string(from: day.date)
        _ = repository.toggleLessonSkipped(dateString: dateStr, lessonNumber: item.lessonNumber, subject: item.subjectName)
        loadSchedule()
        HapticsService.shared.notification(.success)
    }
    
    public func markLessonAttended(item: ScheduleItem, date: Date) {
        let dateStr = DateUtils.isoDateFormatter.string(from: date)
        repository.markLessonAttended(dateString: dateStr, lessonNumber: item.lessonNumber, subject: item.subjectName)
        loadSchedule()
        HapticsService.shared.notification(.success)
    }
    
    public func markLessonSkipped(item: ScheduleItem, date: Date) {
        let dateStr = DateUtils.isoDateFormatter.string(from: date)
        repository.markLessonSkipped(dateString: dateStr, lessonNumber: item.lessonNumber, subject: item.subjectName)
        loadSchedule()
        HapticsService.shared.notification(.warning)
    }
    
    public func clearLessonAttendance(item: ScheduleItem, date: Date) {
        let dateStr = DateUtils.isoDateFormatter.string(from: date)
        repository.clearLessonAttendance(dateString: dateStr, lessonNumber: item.lessonNumber, subject: item.subjectName)
        loadSchedule()
        HapticsService.shared.selection()
    }
    
    public func adjustManualSkips(subjectName: String, delta: Int) {
        repository.adjustManualSkips(group: selectedName, subject: subjectName, delta: delta)
        loadSchedule()
        HapticsService.shared.selection()
    }
    
    public func getAttendanceReport() -> AttendanceManager.AttendanceReport {
        return AttendanceManager.shared.calculateReport(
            groupName: selectedName,
            repository: repository,
            weekCalculator: weekCalculator
        )
    }
    
    public func getWarningForSubject(_ subject: String) -> String? {
        guard isGroup else { return nil }
        return AttendanceManager.shared.getWarningForSubject(subject, groupName: selectedName, repository: repository)
    }
    
    // MARK: - Live Timer Loop
    private func startLiveTimer() {
        Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateClockAndNextLesson()
            }
            .store(in: &cancellables)
    }
    
    public func updateClockAndNextLesson() {
        updateLiveClock()
        updateNextLesson()
        syncLiveLessonNotifications()
    }
    
    private func updateLiveClock() {
        guard let day = currentDaySchedule else { return }
        let isToday = Calendar.current.isDateInToday(day.date)
        if isToday {
            self.clockState = ScheduleClock.compute(for: Date(), scheduleLessons: day.lessons)
        } else {
            self.clockState = ScheduleClockState()
        }
    }
    
    private func updateNextLesson() {
        self.nextUpcomingLesson = repository.findNextLesson(
            targetName: selectedName,
            isGroup: isGroup,
            weekCalculator: weekCalculator
        )
    }
    
    private func syncLiveLessonNotifications() {
        let enabled = (UserDefaults.standard.object(forKey: Constants.prefLiveLessonNotifEnabled) as? Bool) ?? true
        let now = Date()
        let todayStr = DateUtils.isoDateFormatter.string(from: now)
        let lessons = enabled ? todayActiveLessons(for: now) : []
        let sig = lessons.map {
            "\($0.lessonNumber):\($0.subjectName):\($0.room):\($0.isCancelled):\($0.isExcluded):\($0.isSkipped)"
        }.joined(separator: "|")
        let syncKey = "\(enabled)#\(todayStr)#\(selectedName)#\(isGroup)#\(sig)"
        guard syncKey != lastLiveNotifSyncKey else { return }
        lastLiveNotifSyncKey = syncKey
        
        NotificationManager.shared.updateLiveLessonNotifications(
            lessons: lessons,
            date: now,
            enabled: enabled
        )
    }
    
    private func todayActiveLessons(for date: Date) -> [ScheduleItem] {
        guard !selectedName.isEmpty,
              !HolidayChecker.shared.isDayOff(date: date) else {
            return []
        }
        let dow = DateUtils.toScheduleDayOfWeek(date: date)
        guard dow >= 1 && dow <= 6 else { return [] }
        
        if let todayDay = weekDays.first(where: { Calendar.current.isDateInToday($0.date) }) {
            return todayDay.lessons
        }
        
        let weekNum = weekCalculator.getWeekNumber(for: date)
        guard weekNum > 0, let weekType = weekCalculator.getWeekType(for: date) else {
            return []
        }
        let items = repository.getSchedule(for: selectedName, isGroup: isGroup)
        let monday = weekCalculator.getMondayOfWeek(weekNumber: weekNum) ?? DateUtils.mondayOfWeek(for: date)
        let day = scheduleFilter.buildWeekSchedule(
            allItems: items,
            weekNumber: weekNum,
            weekType: weekType,
            mondayOfWeek: monday,
            allTransfers: [],
            targetName: selectedName,
            isGroup: isGroup
        ).days.first(where: { $0.dayOfWeek == dow })
        return day?.lessons ?? []
    }
    
    private func exportWidgetData() {
        guard let day = currentDaySchedule else { return }
        let widgetLessons = day.lessons.map { item in
            WidgetLessonData(
                lessonNumber: item.lessonNumber,
                timeLabel: item.timeLabel,
                subjectName: item.subjectName,
                room: item.room,
                lessonType: item.lessonType,
                teacherOrGroup: isGroup ? item.teacherName : item.groupName
            )
        }
        
        let payload = WidgetSchedulePayload(
            targetName: selectedName,
            isGroup: isGroup,
            dateString: DateUtils.formatDisplayDate(day.date),
            isDayOff: day.isDayOff,
            holidayName: day.holidayName,
            lessons: widgetLessons
        )
        WidgetDataService.shared.exportForWidget(payload: payload)
    }
}
