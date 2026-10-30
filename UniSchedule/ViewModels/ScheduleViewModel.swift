import Foundation
import SwiftUI
import Combine

@MainActor
public final class ScheduleViewModel: ObservableObject {
    @Published public var selectedName: String = ""
    @Published public var isGroup: Bool = true
    @Published public var selectedWeekNumber: Int = 1
    @Published public var selectedDayOfWeek: Int = 1
    
    @Published public var weekSchedule: WeekSchedule? = nil
    @Published public var clockState: ScheduleClockState = ScheduleClockState()
    @Published public var nextUpcomingLesson: NextLesson? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    private let repository = ScheduleRepository.shared
    private let scheduleFilter = ScheduleFilter()
    private var weekCalculator: WeekCalculator
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        let semesterStart = SemesterManager.getDefaultSemesterStart()
        self.weekCalculator = WeekCalculator(semesterStartDate: semesterStart)
        
        // Restore user defaults
        let savedType = UserDefaults.standard.string(forKey: Constants.prefSelectionType) ?? "group"
        let savedName = UserDefaults.standard.string(forKey: Constants.prefSelectionName) ?? "ИВБ-24"
        self.isGroup = (savedType == "group")
        self.selectedName = savedName
        
        // Default to current week & day
        let currentWeek = weekCalculator.currentWeekNumber
        self.selectedWeekNumber = (currentWeek > 0) ? currentWeek : 1
        
        let todayDow = DateUtils.toScheduleDayOfWeek(date: Date())
        self.selectedDayOfWeek = (todayDow >= 1 && todayDow <= 6) ? todayDow : 1
        
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
        
        NotificationCenter.default.publisher(for: NSNotification.Name("AttendanceChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadSchedule()
            }
            .store(in: &cancellables)
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
        
        updateLiveClock()
        updateNextLesson()
        exportWidgetData()
    }
    
    public func refresh() async {
        isLoading = true
        errorMessage = nil
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
            loadSchedule()
            HapticsService.shared.selection()
        }
    }
    
    public func nextWeek() {
        if selectedWeekNumber < SemesterManager.totalWeeks {
            selectedWeekNumber += 1
            loadSchedule()
            HapticsService.shared.selection()
        }
    }
    
    public func resetToCurrentWeekAndDay() {
        let cw = weekCalculator.currentWeekNumber
        self.selectedWeekNumber = (cw > 0) ? cw : 1
        let dow = DateUtils.toScheduleDayOfWeek(date: Date())
        self.selectedDayOfWeek = (dow >= 1 && dow <= 6) ? dow : 1
        loadSchedule()
        HapticsService.shared.selection()
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
                self?.updateLiveClock()
            }
            .store(in: &cancellables)
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
