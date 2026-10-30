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
    
    @Published public var semesterStartDate: Date {
        didSet {
            let str = DateUtils.isoDateFormatter.string(from: semesterStartDate)
            UserDefaults.standard.set(str, forKey: Constants.prefSemesterStart)
        }
    }
    
    @Published public var isRefreshing: Bool = false
    @Published public var cacheStatusMessage: String = ""
    
    private let repository = ScheduleRepository.shared
    
    public init() {
        let savedTheme = UserDefaults.standard.string(forKey: Constants.prefThemeMode) ?? ThemeMode.system.rawValue
        self.themeMode = ThemeMode(rawValue: savedTheme) ?? .system
        
        self.remindersEnabled = UserDefaults.standard.bool(forKey: Constants.prefRemindersEnabled)
        let savedMin = UserDefaults.standard.integer(forKey: Constants.prefReminderMinutesBefore)
        self.reminderMinutesBefore = (savedMin > 0) ? savedMin : 15
        self.morningDigestEnabled = UserDefaults.standard.bool(forKey: Constants.prefMorningDigestEnabled)
        
        if let savedDateStr = UserDefaults.standard.string(forKey: Constants.prefSemesterStart),
           let date = DateUtils.isoDateFormatter.date(from: savedDateStr) {
            self.semesterStartDate = date
        } else {
            self.semesterStartDate = SemesterManager.getDefaultSemesterStart()
        }
        
        updateCacheStatus()
    }
    
    public var semesterDescription: String {
        SemesterManager.describeSemester(startDate: semesterStartDate)
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
    
    private func handleNotificationSettingsChange() {
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
