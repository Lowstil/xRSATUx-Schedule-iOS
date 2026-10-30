import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                // Theme
                Section(header: Text("Оформление")) {
                    Picker("Тема приложения", selection: $viewModel.themeMode) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
                
                // Notifications
                Section(header: Text("Уведомления")) {
                    Toggle("Напоминание перед началом пары", isOn: $viewModel.remindersEnabled)
                    
                    if viewModel.remindersEnabled {
                        Picker("Время напоминания", selection: $viewModel.reminderMinutesBefore) {
                            Text("За 10 минут").tag(10)
                            Text("За 15 минут").tag(15)
                            Text("За 30 минут").tag(30)
                        }
                    }
                    
                    Toggle("Утренний дайджест в 07:30", isOn: $viewModel.morningDigestEnabled)
                }
                
                // Semester
                Section(header: Text("Учебный семестр"), footer: Text(viewModel.semesterDescription)) {
                    DatePicker(
                        "Начало семестра",
                        selection: $viewModel.semesterStartDate,
                        displayedComponents: [.date]
                    )
                }
                
                // Cache & Network
                Section(header: Text("Кэш и данные"), footer: Text(viewModel.cacheStatusMessage)) {
                    Button(action: {
                        Task { await viewModel.forceRefresh() }
                    }) {
                        HStack {
                            Text("Обновить расписание с сайта")
                            Spacer()
                            if viewModel.isRefreshing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isRefreshing)
                    
                    Button("Сбросить кэш", role: .destructive) {
                        viewModel.clearCache()
                    }
                }
                
                // About
                Section(header: Text("О приложении")) {
                    HStack {
                        Text("Версия")
                        Spacer()
                        Text("1.0.0 (iOS)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Университет")
                        Spacer()
                        Text("РГАТУ им. П.А. Соловьёва")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Официальный сайт вуза", destination: URL(string: "https://www.rsatu.ru")!)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}
