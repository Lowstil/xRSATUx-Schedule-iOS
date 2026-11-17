import Foundation
import SwiftUI
import Combine

@MainActor
public final class ScheduleViewModel: ObservableObject {
    public static let weekCount = SemesterManager.totalWeeks
    public static let daysPerWeek = 6
    public static let pagesPerSemester = weekCount * daysPerWeek // 108
    public static let totalPages = pagesPerSemester * 2          // 216

    @Published public var selectedName: String = ""
    @Published public var isGroup: Bool = true
    @Published public var selectedWeekNumber: Int = 1
    @Published public var selectedDayOfWeek: Int = 1 {
        didSet {
            if !isSyncingPageIndex {
                isSyncingPageIndex = true
                currentPageIndex = pageIndex(semester: activeSemester, week: selectedWeekNumber, dayOfWeek: selectedDayOfWeek)
                isSyncingPageIndex = false
            }
            updateLiveClock()
        }
    }

    @Published public var currentPageIndex: Int = 0 {
        didSet {
            guard !isSyncingPageIndex else { return }
            let clamped = min(max(0, currentPageIndex), Self.totalPages - 1)
            if clamped != currentPageIndex {
                isSyncingPageIndex = true
                currentPageIndex = clamped
                isSyncingPageIndex = false
            }
            handleUserPageSelection(clamped)
        }
    }

    @Published public var activeSemester: SemesterType
    @Published public var semesterToastMessage: String? = nil
    @Published public var weekSchedule: WeekSchedule? = nil
    @Published public var clockState: ScheduleClockState = ScheduleClockState()
    @Published public var nextUpcomingLesson: NextLesson? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var skipLimitPercent: Int
    @Published public var activeScheduleDiff: ScheduleDiffResult? = nil
    @Published public var showScheduleDiffSheet: Bool = false
    @Published public private(set) var warningsBySubject: [String: String] = [:]
    @Published public private(set) var pendingNotesCount: Int = 0

    private var weekCache: [String: WeekSchedule] = [:]

    private let repository = ScheduleRepository.shared
    private let scheduleFilter = ScheduleFilter()
    public private(set) var weekCalculator: WeekCalculator
    private var cancellables = Set<AnyCancellable>()
    private var lastLiveNotifSyncKey: String? = nil
    private var selectionGeneration: Int = 0
    private var builtForDate: String = DateUtils.isoDateFormatter.string(from: Date())
    private var isSyncingPageIndex: Bool = false
    private var toastDismissTask: Task<Void, Never>? = nil

    public init() {
        let initialSem = repository.activeSemester
        self.activeSemester = initialSem
        self.weekCalculator = WeekCalculator(semesterStartDate: SemesterManager.loadSemesterStart(for: initialSem))
        self.skipLimitPercent = AttendanceManager.shared.skipLimitPercent
        self.activeScheduleDiff = repository.lastScheduleDiff
        self.pendingNotesCount = repository.pendingNotesCount

        let savedType = UserDefaults.standard.string(forKey: Constants.prefSelectionType) ?? "group"
        let savedName = UserDefaults.standard.string(forKey: Constants.prefSelectionName) ?? "ИВБ-24"
        self.isGroup = (savedType == "group")
        self.selectedName = savedName

        let today = Date()
        let windowSem = SemesterManager.getCurrentWindowSemester(today: today)
        let targetWeek: Int
        let targetDow: Int
        if initialSem == windowSem {
            let targetDate = DateUtils.initialScheduleDate(today) ?? today
            let w = weekCalculator.getWeekNumber(for: targetDate)
            targetWeek = (w > 0) ? min(max(1, w), Self.weekCount) : weekCalculator.currentWeekNumber
            let dow = DateUtils.toScheduleDayOfWeek(date: targetDate)
            targetDow = (dow >= 1 && dow <= Self.daysPerWeek) ? dow : 1
        } else {
            targetWeek = 1
            targetDow = 1
        }

        self.isSyncingPageIndex = true
        self.selectedWeekNumber = targetWeek
        self.selectedDayOfWeek = targetDow
        self.currentPageIndex = pageIndex(semester: initialSem, week: targetWeek, dayOfWeek: targetDow)
        self.isSyncingPageIndex = false

        loadSchedule()
        startLiveTimer()
        bindRepository()
    }

    // MARK: - Unified 216-Page Pager Math
    public func pageIndex(semester: SemesterType, week: Int, dayOfWeek: Int) -> Int {
        let clampedWeek = min(max(1, week), Self.weekCount)
        let clampedDay = min(max(1, dayOfWeek), Self.daysPerWeek)
        let semOffset = (semester == .fall) ? 0 : Self.pagesPerSemester
        return semOffset + (clampedWeek - 1) * Self.daysPerWeek + (clampedDay - 1)
    }

    public func semesterAndWeekAndDay(forPage page: Int) -> (SemesterType, Int, Int) {
        let clamped = min(max(0, page), Self.totalPages - 1)
        let semester: SemesterType = (clamped < Self.pagesPerSemester) ? .fall : .spring
        let localPage = clamped % Self.pagesPerSemester
        let week = (localPage / Self.daysPerWeek) + 1
        let dayOfWeek = (localPage % Self.daysPerWeek) + 1
        return (semester, week, dayOfWeek)
    }

    // MARK: - Semester State & Week Cache
    public var isActiveSemesterPublished: Bool {
        isSemesterPublished(activeSemester)
    }

    public func isSemesterPublished(_ semester: SemesterType) -> Bool {
        repository.isSemesterPublished(semester)
    }

    public func weekCalculator(for semester: SemesterType) -> WeekCalculator {
        if semester == activeSemester {
            return weekCalculator
        }
        return WeekCalculator(semesterStartDate: SemesterManager.loadSemesterStart(for: semester))
    }

    public func weekSchedule(for semester: SemesterType, week: Int) -> WeekSchedule? {
        let clampedWeek = min(max(1, week), Self.weekCount)
        let key = cacheKey(semester: semester, week: clampedWeek)
        if let cached = weekCache[key] {
            return cached
        }
        guard !selectedName.isEmpty, isSemesterPublished(semester) else {
            return nil
        }
        let built = buildWeekSchedule(semester: semester, week: clampedWeek)
        weekCache[key] = built
        return built
    }

    public func ensureWeekLoaded(semester: SemesterType, week: Int) {
        let clampedWeek = min(max(1, week), Self.weekCount)
        let key = cacheKey(semester: semester, week: clampedWeek)
        if weekCache[key] == nil, !selectedName.isEmpty, isSemesterPublished(semester) {
            weekCache[key] = buildWeekSchedule(semester: semester, week: clampedWeek)
        }
        prefetchAdjacentWeeks(semester: semester, week: clampedWeek)
    }

    public func preloadNeighborsIfNeeded(semester: SemesterType, week: Int) {
        let clampedWeek = min(max(1, week), Self.weekCount)
        prefetchAdjacentWeeks(semester: semester, week: clampedWeek)
    }

    private func cacheKey(semester: SemesterType, week: Int) -> String {
        "\(semester.rawValue):\(week)"
    }

    private func clearWeekCache() {
        selectionGeneration += 1
        weekCache.removeAll()
    }

    private func buildWeekSchedule(semester: SemesterType, week: Int) -> WeekSchedule {
        let calc = weekCalculator(for: semester)
        let items = repository.getSchedule(for: selectedName, isGroup: isGroup, semester: semester)
        let custom = repository.getCustomEvents(for: selectedName, isGroup: isGroup)
        let monday = calc.getMondayOfWeek(weekNumber: week) ?? DateUtils.mondayOfWeek(for: SemesterManager.loadSemesterStart(for: semester))
        let weekType = calc.isEvenWeek(week) ? Constants.weekTypeEven : Constants.weekTypeOdd

        return scheduleFilter.buildWeekSchedule(
            allItems: items,
            weekNumber: week,
            weekType: weekType,
            mondayOfWeek: monday,
            allTransfers: [],
            customEvents: custom,
            targetName: selectedName,
            isGroup: isGroup
        )
    }

    private func prefetchAdjacentWeeks(semester: SemesterType, week: Int) {
        let gen = selectionGeneration
        var neighbors: [(SemesterType, Int)] = []
        if week > 1 {
            neighbors.append((semester, week - 1))
        } else if semester == .spring {
            neighbors.append((.fall, Self.weekCount))
        }

        if week < Self.weekCount {
            neighbors.append((semester, week + 1))
        } else if semester == .fall {
            neighbors.append((.spring, 1))
        }

        for (adjSem, adjWeek) in neighbors {
            guard gen == selectionGeneration else { return }
            guard isSemesterPublished(adjSem), !selectedName.isEmpty else { continue }
            let key = cacheKey(semester: adjSem, week: adjWeek)
            if weekCache[key] == nil {
                weekCache[key] = buildWeekSchedule(semester: adjSem, week: adjWeek)
            }
        }
    }

    // MARK: - Bindings
    private func bindRepository() {
        repository.$allItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.clearWeekCache()
                self.loadSchedule()
            }
            .store(in: &cancellables)

        repository.$activeSemester
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newSem in
                guard let self, newSem != self.activeSemester else { return }
                self.activeSemester = newSem
                self.weekCalculator = WeekCalculator(semesterStartDate: SemesterManager.loadSemesterStart(for: newSem))
                self.clearWeekCache()
                self.loadSchedule()
            }
            .store(in: &cancellables)

        repository.$customEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.clearWeekCache()
                self.loadSchedule()
            }
            .store(in: &cancellables)

        repository.$notes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.pendingNotesCount = self.repository.pendingNotesCount
            }
            .store(in: &cancellables)

        repository.$pendingNotesCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.pendingNotesCount = count
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
                guard let self else { return }
                self.clearWeekCache()
                self.loadSchedule()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("SemesterConfigChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.weekCalculator = WeekCalculator(semesterStartDate: SemesterManager.loadSemesterStart(for: self.activeSemester))
                self.clearWeekCache()
                self.loadSchedule()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("NotificationSettingsChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.lastLiveNotifSyncKey = nil
                self.syncLiveLessonNotifications()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("SelectionTargetChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let savedType = UserDefaults.standard.string(forKey: Constants.prefSelectionType) ?? "group"
                let savedName = UserDefaults.standard.string(forKey: Constants.prefSelectionName) ?? "ИВБ-24"
                let nextIsGroup = (savedType == "group")
                if savedName != self.selectedName || nextIsGroup != self.isGroup {
                    self.selectedName = savedName
                    self.isGroup = nextIsGroup
                    self.clearWeekCache()
                    self.loadSchedule()
                }
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
        repository.saveFastTargetCache(for: activeSemester, targetName: name, isGroup: isGroup)

        clearWeekCache()
        loadSchedule()
    }

    public func loadSchedule() {
        builtForDate = DateUtils.isoDateFormatter.string(from: Date())
        guard !selectedName.isEmpty else { return }

        if isSemesterPublished(activeSemester) {
            ensureWeekLoaded(semester: activeSemester, week: selectedWeekNumber)
            self.weekSchedule = weekSchedule(for: activeSemester, week: selectedWeekNumber)
        } else {
            self.weekSchedule = nil
        }

        recomputeWarningsBySubject()
        lastLiveNotifSyncKey = nil
        updateClockAndNextLesson()
        exportWidgetData()
    }

    public func refresh() async {
        let gen = selectionGeneration
        isLoading = true
        errorMessage = nil
        do {
            try await repository.refreshSchedule()
            guard gen == selectionGeneration else {
                isLoading = false
                return
            }
            self.activeSemester = repository.activeSemester
            self.weekCalculator = WeekCalculator(semesterStartDate: SemesterManager.loadSemesterStart(for: activeSemester))
            clearWeekCache()
            loadSchedule()
            HapticsService.shared.notification(.success)
        } catch {
            self.errorMessage = "Не удалось обновить: \(error.localizedDescription)"
            HapticsService.shared.notification(.error)
        }
        isLoading = false
    }

    // MARK: - Navigation & Dual-Semester Switching
    private func handleUserPageSelection(_ page: Int) {
        let (sem, week, dow) = semesterAndWeekAndDay(forPage: page)
        if sem != activeSemester {
            switchActiveSemester(sem, showToast: true, preservePage: true)
        }
        isSyncingPageIndex = true
        selectedWeekNumber = week
        selectedDayOfWeek = dow
        isSyncingPageIndex = false

        if isSemesterPublished(sem) {
            ensureWeekLoaded(semester: sem, week: week)
            self.weekSchedule = weekSchedule(for: sem, week: week)
        } else {
            self.weekSchedule = nil
        }

        updateLiveClock()
        HapticsService.shared.selection()
    }

    public func switchActiveSemester(_ semester: SemesterType, showToast: Bool = true) {
        switchActiveSemester(semester, showToast: showToast, preservePage: false)
    }

    private func switchActiveSemester(_ semester: SemesterType, showToast: Bool, preservePage: Bool) {
        let changed = (semester != activeSemester)
        if changed {
            repository.setActiveSemester(semester)
            self.activeSemester = semester
            self.weekCalculator = WeekCalculator(semesterStartDate: SemesterManager.loadSemesterStart(for: semester))
        }

        if showToast && (changed || semesterToastMessage == nil) {
            let base = "\(semester.toastEmoji) \(semester.displayName)"
            let suffix = isSemesterPublished(semester) ? "" : " · нет расписания"
            semesterToastMessage = base + suffix
            toastDismissTask?.cancel()
            toastDismissTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.semesterToastMessage = nil
                }
            }
        }

        if !preservePage {
            let today = Date()
            let windowSem = SemesterManager.getCurrentWindowSemester(today: today)
            let targetWeek: Int
            let targetDow: Int
            if semester == windowSem {
                let targetDate = DateUtils.initialScheduleDate(today) ?? today
                let w = weekCalculator.getWeekNumber(for: targetDate)
                targetWeek = (w > 0) ? min(max(1, w), Self.weekCount) : weekCalculator.currentWeekNumber
                let dow = DateUtils.toScheduleDayOfWeek(date: targetDate)
                targetDow = (dow >= 1 && dow <= Self.daysPerWeek) ? dow : 1
            } else {
                targetWeek = 1
                targetDow = 1
            }
            isSyncingPageIndex = true
            selectedWeekNumber = targetWeek
            selectedDayOfWeek = targetDow
            currentPageIndex = pageIndex(semester: semester, week: targetWeek, dayOfWeek: targetDow)
            isSyncingPageIndex = false
            loadSchedule()
        }
    }

    public func previousWeek() {
        if selectedWeekNumber > 1 {
            selectedWeekNumber -= 1
            isSyncingPageIndex = true
            selectedDayOfWeek = 1
            currentPageIndex = pageIndex(semester: activeSemester, week: selectedWeekNumber, dayOfWeek: 1)
            isSyncingPageIndex = false
            loadSchedule()
            HapticsService.shared.selection()
        } else if activeSemester == .spring {
            switchActiveSemester(.fall, showToast: true, preservePage: true)
            isSyncingPageIndex = true
            selectedWeekNumber = Self.weekCount
            selectedDayOfWeek = 1
            currentPageIndex = pageIndex(semester: .fall, week: Self.weekCount, dayOfWeek: 1)
            isSyncingPageIndex = false
            loadSchedule()
            HapticsService.shared.selection()
        }
    }

    public func nextWeek() {
        if selectedWeekNumber < Self.weekCount {
            selectedWeekNumber += 1
            isSyncingPageIndex = true
            selectedDayOfWeek = 1
            currentPageIndex = pageIndex(semester: activeSemester, week: selectedWeekNumber, dayOfWeek: 1)
            isSyncingPageIndex = false
            loadSchedule()
            HapticsService.shared.selection()
        } else if activeSemester == .fall {
            switchActiveSemester(.spring, showToast: true, preservePage: true)
            isSyncingPageIndex = true
            selectedWeekNumber = 1
            selectedDayOfWeek = 1
            currentPageIndex = pageIndex(semester: .spring, week: 1, dayOfWeek: 1)
            isSyncingPageIndex = false
            loadSchedule()
            HapticsService.shared.selection()
        }
    }

    public func jumpToToday() {
        let today = Date()
        let windowSem = SemesterManager.getCurrentWindowSemester(today: today)
        if windowSem != activeSemester {
            switchActiveSemester(windowSem, showToast: true, preservePage: true)
        } else {
            weekCalculator = WeekCalculator(semesterStartDate: SemesterManager.loadSemesterStart(for: windowSem))
        }

        let targetDate = DateUtils.initialScheduleDate(today) ?? today
        let w = weekCalculator.getWeekNumber(for: targetDate)
        let targetWeek = (w > 0) ? min(max(1, w), Self.weekCount) : weekCalculator.currentWeekNumber
        let dow = DateUtils.toScheduleDayOfWeek(date: targetDate)
        let targetDay = (dow >= 1 && dow <= Self.daysPerWeek) ? dow : 1

        isSyncingPageIndex = true
        self.selectedWeekNumber = targetWeek
        self.selectedDayOfWeek = targetDay
        self.currentPageIndex = pageIndex(semester: windowSem, week: targetWeek, dayOfWeek: targetDay)
        isSyncingPageIndex = false

        loadSchedule()
        HapticsService.shared.selection()
    }

    public func resetToCurrentWeekAndDay() {
        jumpToToday()
    }

    public func navigateToDate(_ date: Date) {
        var targetSem = SemesterManager.getCurrentWindowSemester(today: date)
        var calc = weekCalculator(for: targetSem)
        var computedWeek = calc.getWeekNumber(for: date)

        if computedWeek < 1 {
            let otherSem = targetSem.other
            let otherCalc = weekCalculator(for: otherSem)
            let otherWeek = otherCalc.getWeekNumber(for: date)
            if otherWeek >= 1 && otherWeek <= Self.weekCount {
                targetSem = otherSem
                computedWeek = otherWeek
            } else {
                computedWeek = 1
            }
        }
        computedWeek = min(max(1, computedWeek), Self.weekCount)

        let dow = DateUtils.toScheduleDayOfWeek(date: date)
        let targetDay = (dow >= 1 && dow <= Self.daysPerWeek) ? dow : 1

        if targetSem != activeSemester {
            switchActiveSemester(targetSem, showToast: true, preservePage: true)
        }

        isSyncingPageIndex = true
        self.selectedWeekNumber = computedWeek
        self.selectedDayOfWeek = targetDay
        self.currentPageIndex = pageIndex(semester: targetSem, week: computedWeek, dayOfWeek: targetDay)
        isSyncingPageIndex = false

        loadSchedule()
        HapticsService.shared.selection()
    }

    public func selectDay(_ dow: Int) {
        guard dow >= 1 && dow <= Self.daysPerWeek else { return }
        isSyncingPageIndex = true
        self.selectedDayOfWeek = dow
        self.currentPageIndex = pageIndex(semester: activeSemester, week: selectedWeekNumber, dayOfWeek: dow)
        isSyncingPageIndex = false
        updateLiveClock()
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

    // MARK: - Personal Events
    public func addCustomEvent(_ event: CustomEvent) {
        repository.addCustomEvent(event)
        clearWeekCache()
        loadSchedule()
        HapticsService.shared.notification(.success)
    }

    public func deleteCustomEvent(id: UUID) {
        repository.deleteCustomEvent(id: id)
        clearWeekCache()
        loadSchedule()
        HapticsService.shared.notification(.warning)
    }

    // MARK: - Two-Group Schedule Comparison
    public func buildDayComparison(
        group1: String,
        group2: String,
        semester: SemesterType,
        weekNumber: Int,
        dayOfWeek: Int
    ) -> CompareResult {
        let clampedWeek = min(max(1, weekNumber), Self.weekCount)
        let clampedDow = min(max(1, dayOfWeek), Self.daysPerWeek)
        let calc = weekCalculator(for: semester)
        let monday = calc.getMondayOfWeek(weekNumber: clampedWeek) ?? DateUtils.mondayOfWeek(for: SemesterManager.loadSemesterStart(for: semester))
        let weekType = calc.isEvenWeek(clampedWeek) ? Constants.weekTypeEven : Constants.weekTypeOdd

        let items1 = repository.getSchedule(for: group1, isGroup: true, semester: semester)
        let custom1 = repository.getCustomEvents(for: group1, isGroup: true)
        let week1 = scheduleFilter.buildWeekSchedule(
            allItems: items1,
            weekNumber: clampedWeek,
            weekType: weekType,
            mondayOfWeek: monday,
            allTransfers: [],
            customEvents: custom1,
            targetName: group1,
            isGroup: true
        )

        let items2 = repository.getSchedule(for: group2, isGroup: true, semester: semester)
        let custom2 = repository.getCustomEvents(for: group2, isGroup: true)
        let week2 = scheduleFilter.buildWeekSchedule(
            allItems: items2,
            weekNumber: clampedWeek,
            weekType: weekType,
            mondayOfWeek: monday,
            allTransfers: [],
            customEvents: custom2,
            targetName: group2,
            isGroup: true
        )

        return ScheduleFilter.buildDayComparison(
            group1: group1,
            group2: group2,
            week1: week1,
            week2: week2,
            semester: semester,
            weekNumber: clampedWeek,
            dayOfWeek: clampedDow
        )
    }

    // MARK: - Actions on Lessons & Attendance
    public func toggleSkippedLesson(item: ScheduleItem) {
        guard let day = currentDaySchedule else { return }
        let dateStr = DateUtils.isoDateFormatter.string(from: day.date)
        _ = repository.toggleLessonSkipped(dateString: dateStr, lessonNumber: item.lessonNumber, subject: item.subjectName)
        clearWeekCache()
        loadSchedule()
        HapticsService.shared.notification(.success)
    }

    public func markLessonAttended(item: ScheduleItem, date: Date) {
        let dateStr = DateUtils.isoDateFormatter.string(from: date)
        repository.markLessonAttended(dateString: dateStr, lessonNumber: item.lessonNumber, subject: item.subjectName)
        clearWeekCache()
        loadSchedule()
        HapticsService.shared.notification(.success)
    }

    public func markLessonSkipped(item: ScheduleItem, date: Date) {
        let dateStr = DateUtils.isoDateFormatter.string(from: date)
        repository.markLessonSkipped(dateString: dateStr, lessonNumber: item.lessonNumber, subject: item.subjectName)
        clearWeekCache()
        loadSchedule()
        HapticsService.shared.notification(.warning)
    }

    public func clearLessonAttendance(item: ScheduleItem, date: Date) {
        let dateStr = DateUtils.isoDateFormatter.string(from: date)
        repository.clearLessonAttendance(dateString: dateStr, lessonNumber: item.lessonNumber, subject: item.subjectName)
        clearWeekCache()
        loadSchedule()
        HapticsService.shared.selection()
    }

    public func adjustManualSkips(subjectName: String, delta: Int) {
        repository.adjustManualSkips(group: selectedName, subject: subjectName, delta: delta)
        clearWeekCache()
        loadSchedule()
        HapticsService.shared.selection()
    }

    public func getAttendanceReport(semester: SemesterType? = nil) -> AttendanceManager.AttendanceReport {
        let sem = semester ?? activeSemester
        return AttendanceManager.shared.calculateReport(
            groupName: selectedName,
            semester: sem,
            repository: repository,
            weekCalculator: weekCalculator(for: sem)
        )
    }

    private func recomputeWarningsBySubject() {
        guard isGroup, !selectedName.isEmpty, isSemesterPublished(activeSemester) else {
            if !warningsBySubject.isEmpty {
                warningsBySubject = [:]
            }
            return
        }

        let report = AttendanceManager.shared.calculateReport(
            groupName: selectedName,
            semester: activeSemester,
            repository: repository,
            weekCalculator: weekCalculator
        )
        var nextWarnings: [String: String] = [:]
        for sa in report.subjects where sa.hasWarning {
            nextWarnings[sa.subjectName] = "🟡 Внимание: уже \(AttendanceManager.formatSkips(sa.missedCount)), пора ходить!"
        }
        if nextWarnings != warningsBySubject {
            warningsBySubject = nextWarnings
        }
    }

    public func getWarningForSubject(_ subject: String) -> String? {
        guard isGroup else { return nil }
        return warningsBySubject[subject]
            ?? warningsBySubject[subject.trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    // MARK: - Live Timer Loop
    private func startLiveTimer() {
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateClockAndNextLesson()
            }
            .store(in: &cancellables)
    }

    public func updateClockAndNextLesson() {
        let todayStr = DateUtils.isoDateFormatter.string(from: Date())
        if todayStr != builtForDate {
            builtForDate = todayStr
            clearWeekCache()
            loadSchedule()
            return
        }
        updateLiveClock()
        updateNextLesson()
        syncLiveLessonNotifications()
    }

    private func updateLiveClock() {
        let newClock: ScheduleClockState
        if let day = currentDaySchedule, Calendar.current.isDateInToday(day.date) {
            newClock = ScheduleClock.compute(for: Date(), scheduleLessons: day.lessons)
        } else {
            newClock = ScheduleClockState()
        }
        if newClock != self.clockState {
            self.clockState = newClock
        }
    }

    private func updateNextLesson() {
        let windowSem = SemesterManager.getCurrentWindowSemester(today: Date())
        let sem = isSemesterPublished(windowSem) ? windowSem : activeSemester
        let next = repository.findNextLesson(
            targetName: selectedName,
            isGroup: isGroup,
            weekCalculator: weekCalculator(for: sem),
            semester: sem
        )
        if !Self.isSameNextLesson(next, self.nextUpcomingLesson) {
            self.nextUpcomingLesson = next
        }
    }

    private static func isSameNextLesson(_ a: NextLesson?, _ b: NextLesson?) -> Bool {
        switch (a, b) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return lhs.subjectName == rhs.subjectName &&
                lhs.lessonType == rhs.lessonType &&
                lhs.room == rhs.room &&
                lhs.teacherOrGroup == rhs.teacherOrGroup &&
                lhs.lessonNumber == rhs.lessonNumber &&
                lhs.timeStart == rhs.timeStart &&
                lhs.timeEnd == rhs.timeEnd &&
                Calendar.current.isDate(lhs.date, inSameDayAs: rhs.date)
        default:
            return false
        }
    }

    private func syncLiveLessonNotifications() {
        let enabled = (UserDefaults.standard.object(forKey: Constants.prefLiveLessonNotifEnabled) as? Bool) ?? true
        let now = Date()
        let todayStr = DateUtils.isoDateFormatter.string(from: now)
        let lessons = enabled ? todayActiveLessons(for: now) : []
        let activeNumber = ScheduleClock.compute(for: now, scheduleLessons: lessons).currentLessonNumber ?? -1
        let sig = lessons.map {
            "\($0.lessonNumber):\($0.subjectName):\($0.room):\($0.isCancelled):\($0.isExcluded):\($0.isSkipped)"
        }.joined(separator: "|")
        let syncKey = "\(enabled)#\(todayStr)#\(selectedName)#\(isGroup)#\(activeNumber)#\(sig)"
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
        guard dow >= 1 && dow <= Self.daysPerWeek else { return [] }

        let windowSem = SemesterManager.getCurrentWindowSemester(today: date)
        let sem = isSemesterPublished(windowSem) ? windowSem : activeSemester
        return buildDaySchedule(for: date, semester: sem).lessons
    }

    private func buildDaySchedule(for date: Date, semester: SemesterType) -> DaySchedule {
        let dow = DateUtils.toScheduleDayOfWeek(date: date)
        if HolidayChecker.shared.isDayOff(date: date) || dow < 1 || dow > Self.daysPerWeek {
            return DaySchedule(
                dayOfWeek: max(1, dow),
                date: date,
                lessons: [],
                isDayOff: true,
                holidayName: HolidayChecker.shared.getHolidayName(date: date)
            )
        }

        let calc = weekCalculator(for: semester)
        let weekNum = calc.getWeekNumber(for: date)
        let custom = repository.getCustomEvents(for: selectedName, isGroup: isGroup)

        if weekNum >= 1 && weekNum <= Self.weekCount {
            let items = repository.getSchedule(for: selectedName, isGroup: isGroup, semester: semester)
            let monday = calc.getMondayOfWeek(weekNumber: weekNum) ?? DateUtils.mondayOfWeek(for: date)
            let weekType = calc.isEvenWeek(weekNum) ? Constants.weekTypeEven : Constants.weekTypeOdd
            let week = scheduleFilter.buildWeekSchedule(
                allItems: items,
                weekNumber: weekNum,
                weekType: weekType,
                mondayOfWeek: monday,
                allTransfers: [],
                customEvents: custom,
                targetName: selectedName,
                isGroup: isGroup
            )
            if let day = week.days.first(where: { $0.dayOfWeek == dow }) {
                return day
            }
        }

        // Outside weeks 1..18: still allow one-time custom events on that exact date
        let oneTimeLessons = custom
            .filter { !$0.isRecurring && $0.matchesDate(date, dayOfWeek: dow, weekType: "") }
            .map { $0.toScheduleItem(dayOfWeek: dow, isGroup: isGroup) }
            .sorted { $0.lessonNumber < $1.lessonNumber }
        return DaySchedule(dayOfWeek: dow, date: date, lessons: oneTimeLessons, isDayOff: false)
    }

    // MARK: - Widget Tomorrow Preview Resolution
    public func resolveWidgetPayload() -> WidgetSchedulePayload? {
        guard !selectedName.isEmpty else { return nil }
        let now = Date()
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)
        let windowSem = SemesterManager.getCurrentWindowSemester(today: now)
        let sem = isSemesterPublished(windowSem) ? windowSem : activeSemester

        let todayDay = buildDaySchedule(for: todayStart, semester: sem)
        let hasRemainingToday = hasRemainingLessons(in: todayDay, now: now, calendar: cal)

        if hasRemainingToday {
            return WidgetSchedulePayload(
                targetName: selectedName,
                isGroup: isGroup,
                dateString: DateUtils.formatDisplayDate(todayDay.date),
                isDayOff: todayDay.isDayOff,
                holidayName: todayDay.holidayName,
                lessons: mapWidgetLessons(todayDay.lessons),
                isPreview: false,
                previewLabel: nil,
                semesterId: sem.rawValue
            )
        }

        // Advance to tomorrow (skipping Sunday -> Monday)
        var candidate = cal.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        if DateUtils.toScheduleDayOfWeek(date: candidate) == 0 {
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }

        let candidateWindowSem = SemesterManager.getCurrentWindowSemester(today: candidate)
        let candidateSem = isSemesterPublished(candidateWindowSem) ? candidateWindowSem : sem
        let candidateDay = buildDaySchedule(for: candidate, semester: candidateSem)
        let candidateActive = candidateDay.lessons.filter { !$0.isCancelled && !$0.isExcluded && !$0.isSkipped }

        if !candidateDay.isDayOff && !candidateActive.isEmpty {
            let daysDiff = DateUtils.daysBetween(todayStart, candidate)
            let dowIndex = max(0, min(Constants.dayNamesShort.count - 1, candidateDay.dayOfWeek - 1))
            let dayShort = Constants.dayNamesShort[dowIndex]
            let label = (daysDiff == 1)
                ? "Завтра · \(dayShort)"
                : "\(dayShort), \(DateUtils.formatDisplayDateShort(candidate))"

            return WidgetSchedulePayload(
                targetName: selectedName,
                isGroup: isGroup,
                dateString: DateUtils.formatDisplayDate(candidate),
                isDayOff: false,
                holidayName: nil,
                lessons: mapWidgetLessons(candidateDay.lessons),
                isPreview: true,
                previewLabel: label,
                semesterId: candidateSem.rawValue
            )
        }

        return WidgetSchedulePayload(
            targetName: selectedName,
            isGroup: isGroup,
            dateString: DateUtils.formatDisplayDate(todayDay.date),
            isDayOff: todayDay.isDayOff,
            holidayName: todayDay.holidayName,
            lessons: mapWidgetLessons(todayDay.lessons),
            isPreview: false,
            previewLabel: nil,
            semesterId: sem.rawValue
        )
    }

    private func hasRemainingLessons(in day: DaySchedule, now: Date, calendar: Calendar) -> Bool {
        guard !day.isDayOff else { return false }
        let times = Constants.getLessonTimes(dayOfWeek: day.dayOfWeek)
        let baseComps = calendar.dateComponents([.year, .month, .day], from: day.date)

        for item in day.lessons where !item.isCancelled && !item.isExcluded && !item.isSkipped {
            guard item.lessonNumber >= 1 && item.lessonNumber <= times.count else { continue }
            let endParts = times[item.lessonNumber - 1].end.split(separator: ":")
            guard endParts.count == 2,
                  let h = Int(endParts[0]),
                  let m = Int(endParts[1]) else { continue }
            var comps = baseComps
            comps.hour = h
            comps.minute = m
            if let lessonEnd = calendar.date(from: comps), now < lessonEnd {
                return true
            }
        }
        return false
    }

    private func mapWidgetLessons(_ lessons: [ScheduleItem]) -> [WidgetLessonData] {
        lessons
            .filter { !$0.isCancelled && !$0.isExcluded }
            .sorted { $0.lessonNumber < $1.lessonNumber }
            .map { item in
                WidgetLessonData(
                    lessonNumber: item.lessonNumber,
                    timeLabel: item.timeLabel,
                    subjectName: item.subjectName,
                    room: item.room,
                    lessonType: item.lessonType,
                    teacherOrGroup: isGroup ? item.teacherName : item.groupName
                )
            }
    }

    private func exportWidgetData() {
        guard let payload = resolveWidgetPayload() else { return }
        WidgetDataService.shared.exportForWidget(payload: payload)
    }
}
