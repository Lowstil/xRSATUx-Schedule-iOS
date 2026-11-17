import Foundation
import SwiftUI
import Combine

public enum ThemeMode: String, CaseIterable, Identifiable {
    case system = "Системная"
    case light = "Светлая"
    case dark = "Тёмная"

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: Constants.prefThemeMode)
        }
    }

    @Published public var remindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(remindersEnabled, forKey: Constants.prefRemindersEnabled)
            handleNotificationSettingsChange()
        }
    }

    @Published public var reminderMinutesBefore: Int {
        didSet {
            UserDefaults.standard.set(reminderMinutesBefore, forKey: Constants.prefReminderMinutesBefore)
            handleNotificationSettingsChange()
        }
    }

    @Published public var morningDigestEnabled: Bool {
        didSet {
            UserDefaults.standard.set(morningDigestEnabled, forKey: Constants.prefMorningDigestEnabled)
            handleNotificationSettingsChange()
        }
    }

    @Published public var selectedSemester: SemesterType

    @Published public var semesterStartDate: Date {
        didSet {
            guard !isSyncingSemesterDate else { return }
            let normalized = DateUtils.mondayOfWeek(for: semesterStartDate)
            if normalized != semesterStartDate {
                isSyncingSemesterDate = true
                semesterStartDate = normalized
                isSyncingSemesterDate = false
            }
            SemesterManager.saveSemesterStart(normalized, for: selectedSemester)
            NotificationCenter.default.post(name: NSNotification.Name("SemesterConfigChanged"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("NotificationSettingsChanged"), object: nil)
        }
    }

    @Published public var reducedTransparency: Bool {
        didSet {
            UserDefaults.standard.set(reducedTransparency, forKey: Constants.prefReducedTransparency)
        }
    }

    @Published public var liveLessonNotifEnabled: Bool {
        didSet {
            UserDefaults.standard.set(liveLessonNotifEnabled, forKey: Constants.prefLiveLessonNotifEnabled)
            if !liveLessonNotifEnabled {
                NotificationManager.shared.cancelLiveLessonNotifications()
            } else {
                Task {
                    _ = await NotificationManager.shared.requestAuthorization()
                }
            }
            NotificationCenter.default.post(name: NSNotification.Name("NotificationSettingsChanged"), object: nil)
        }
    }

    @Published public var isRefreshing: Bool = false
    @Published public var cacheStatusMessage: String = ""

    private let repository = ScheduleRepository.shared
    private var cancellables = Set<AnyCancellable>()
    private var isSyncingSemesterDate = false

    public var hasScheduleDiff: Bool {
        ScheduleRepository.shared.lastScheduleDiff?.isEmpty == false
    }

    public init() {
        let savedTheme = UserDefaults.standard.string(forKey: Constants.prefThemeMode) ?? ThemeMode.system.rawValue
        self.themeMode = ThemeMode(rawValue: savedTheme) ?? .system

        self.remindersEnabled = UserDefaults.standard.bool(forKey: Constants.prefRemindersEnabled)
        let savedMin = UserDefaults.standard.integer(forKey: Constants.prefReminderMinutesBefore)
        self.reminderMinutesBefore = (savedMin > 0) ? savedMin : 15
        self.morningDigestEnabled = UserDefaults.standard.bool(forKey: Constants.prefMorningDigestEnabled)
        self.reducedTransparency = UserDefaults.standard.bool(forKey: Constants.prefReducedTransparency)
        self.liveLessonNotifEnabled = (UserDefaults.standard.object(forKey: Constants.prefLiveLessonNotifEnabled) as? Bool) ?? true

        let activeSem = repository.activeSemester
        self.selectedSemester = activeSem
        self.semesterStartDate = SemesterManager.loadSemesterStart(for: activeSem)

        updateCacheStatus()

        repository.$activeSemester
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newSem in
                guard let self, newSem != self.selectedSemester else { return }
                self.selectedSemester = newSem
                self.isSyncingSemesterDate = true
                self.semesterStartDate = SemesterManager.loadSemesterStart(for: newSem)
                self.isSyncingSemesterDate = false
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("AttendanceChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("SelectionTargetChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var currentSelectionName: String {
        UserDefaults.standard.string(forKey: Constants.prefSelectionName) ?? "ИВБ-24"
    }

    public var currentSelectionIsGroup: Bool {
        (UserDefaults.standard.string(forKey: Constants.prefSelectionType) ?? "group") == "group"
    }

    public var allSubjectsForCurrentGroup: [String] {
        repository.getAllSubjects(for: currentSelectionName)
    }

    public var excludedSubjectsSummary: String {
        let excluded = repository.getExcludedSubjects(for: currentSelectionName)
        return excluded.isEmpty ? "Нет исключённых предметов" : "Исключено предметов: \(excluded.count)"
    }

    public func selectTarget(name: String, isGroup: Bool) {
        UserDefaults.standard.set(isGroup ? "group" : "teacher", forKey: Constants.prefSelectionType)
        UserDefaults.standard.set(name, forKey: Constants.prefSelectionName)
        repository.saveFastTargetCache(for: repository.activeSemester, targetName: name, isGroup: isGroup)
        NotificationCenter.default.post(name: NSNotification.Name("SelectionTargetChanged"), object: nil)
        objectWillChange.send()
    }

    public func buildCurrentExportData() -> (day: DaySchedule?, week: WeekSchedule?, targetName: String, isGroup: Bool) {
        let targetName = currentSelectionName
        let isGroup = currentSelectionIsGroup
        let sem = repository.activeSemester
        guard !targetName.isEmpty, repository.isSemesterPublished(sem) else {
            return (nil, nil, targetName, isGroup)
        }

        let today = Date()
        let windowSem = SemesterManager.getCurrentWindowSemester(today: today)
        let calc = WeekCalculator(semesterStartDate: SemesterManager.loadSemesterStart(for: sem))
        let targetDate = DateUtils.initialScheduleDate(today) ?? today
        let weekNum: Int
        let dow: Int
        if sem == windowSem {
            let w = calc.getWeekNumber(for: targetDate)
            weekNum = (w > 0) ? min(max(1, w), SemesterManager.totalWeeks) : calc.currentWeekNumber
            let d = DateUtils.toScheduleDayOfWeek(date: targetDate)
            dow = (d >= 1 && d <= 6) ? d : 1
        } else {
            weekNum = 1
            dow = 1
        }

        let monday = calc.getMondayOfWeek(weekNumber: weekNum)
            ?? DateUtils.mondayOfWeek(for: SemesterManager.loadSemesterStart(for: sem))
        let weekType = calc.isEvenWeek(weekNum) ? Constants.weekTypeEven : Constants.weekTypeOdd
        let items = repository.getSchedule(for: targetName, isGroup: isGroup, semester: sem)
        let custom = repository.getCustomEvents(for: targetName, isGroup: isGroup)
        let week = ScheduleFilter().buildWeekSchedule(
            allItems: items,
            weekNumber: weekNum,
            weekType: weekType,
            mondayOfWeek: monday,
            allTransfers: [],
            customEvents: custom,
            targetName: targetName,
            isGroup: isGroup
        )
        let day = week.days.first(where: { $0.dayOfWeek == dow })
        return (day, week, targetName, isGroup)
    }

    public var semesterDescription: String {
        SemesterManager.describeSemester(selectedSemester, startDate: semesterStartDate)
    }

    public var selectedSemesterShortLabel: String {
        "Выбранный семестр: \(selectedSemester.shortName)"
    }

    public var aboutVersionText: String {
        "Версия: v\(Constants.aboutVersion)"
    }

    public var lastUpdatedFormatted: String {
        guard let lu = repository.lastUpdated else {
            return "Последнее обновление расписания: «Ещё не обновлялось»"
        }
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm"
        f.locale = Locale(identifier: "ru_RU")
        return "Последнее обновление расписания: \(f.string(from: lu))"
    }

    public func selectSemester(_ semester: SemesterType) {
        guard semester != selectedSemester else { return }
        selectedSemester = semester
        isSyncingSemesterDate = true
        semesterStartDate = SemesterManager.loadSemesterStart(for: semester)
        isSyncingSemesterDate = false
        repository.setActiveSemester(semester)
        NotificationCenter.default.post(name: NSNotification.Name("SemesterConfigChanged"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("NotificationSettingsChanged"), object: nil)
        updateCacheStatus()
        HapticsService.shared.selection()
    }

    public func updateCacheStatus() {
        if let lu = repository.lastUpdated {
            self.cacheStatusMessage = "Данные обновлены: \(DateUtils.formatDisplayDate(lu))"
        } else {
            self.cacheStatusMessage = "Используется базовое расписание"
        }
    }

    public func forceRefresh() async {
        isRefreshing = true
        do {
            try await repository.refreshSchedule()
            selectedSemester = repository.activeSemester
            isSyncingSemesterDate = true
            semesterStartDate = SemesterManager.loadSemesterStart(for: selectedSemester)
            isSyncingSemesterDate = false
            updateCacheStatus()
            HapticsService.shared.notification(.success)
        } catch {
            self.cacheStatusMessage = "Ошибка обновления: \(error.localizedDescription)"
            HapticsService.shared.notification(.error)
        }
        isRefreshing = false
    }

    public func clearCache() {
        repository.loadFromCacheOrBundle()
        updateCacheStatus()
        HapticsService.shared.notification(.warning)
    }

    public func clearAllData() {
        repository.clearAllData()
        selectedSemester = repository.activeSemester
        isSyncingSemesterDate = true
        semesterStartDate = SemesterManager.loadSemesterStart(for: selectedSemester)
        isSyncingSemesterDate = false
        NotificationCenter.default.post(name: NSNotification.Name("SemesterConfigChanged"), object: nil)
        updateCacheStatus()
        HapticsService.shared.notification(.warning)
    }

    private func handleNotificationSettingsChange() {
        NotificationCenter.default.post(name: NSNotification.Name("NotificationSettingsChanged"), object: nil)
        if remindersEnabled || morningDigestEnabled {
            Task {
                let granted = await NotificationManager.shared.requestAuthorization()
                if !granted {
                    await MainActor.run {
                        self.remindersEnabled = false
                        self.morningDigestEnabled = false
                    }
                }
            }
        } else {
            NotificationManager.shared.cancelAllReminders()
        }
    }
}
