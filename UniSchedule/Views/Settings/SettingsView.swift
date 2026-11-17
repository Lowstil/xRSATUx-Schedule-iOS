import SwiftUI

private struct SettingsExportTarget: Identifiable {
    let id = UUID()
    let day: DaySchedule?
    let week: WeekSchedule?
    let targetName: String
    let isGroup: Bool
}

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var repository = ScheduleRepository.shared

    @State private var showingSelectionSheet = false
    @State private var showingFinderSheet = false
    @State private var showingDiffSheet = false
    @State private var showingBellSheet = false
    @State private var showingExcludedSheet = false
    @State private var exportTarget: SettingsExportTarget? = nil
    @State private var showingClearDataDialog = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(reducedTransparency: viewModel.reducedTransparency)
                    .animation(.easeInOut(duration: 0.25), value: viewModel.reducedTransparency)

                ScrollView {
                    VStack(spacing: 16) {
                        // 1. Текущий выбор (cardSelection)
                        glassSection(title: "Текущий выбор") {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.16))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: viewModel.currentSelectionIsGroup ? "person.2.fill" : "person.fill")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.accentColor)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewModel.currentSelectionName.isEmpty ? "Не выбрано" : viewModel.currentSelectionName)
                                        .font(.headline.bold())
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    Text(viewModel.currentSelectionIsGroup ? "Учебная группа" : "Преподаватель")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer(minLength: 8)

                                Button(action: {
                                    HapticsService.shared.selection()
                                    showingSelectionSheet = true
                                }) {
                                    Text("Сменить")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.accentColor)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .liquidGlassCapsule(tint: .accentColor, reducedTransparency: viewModel.reducedTransparency)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // 2. Инструменты (cardTools)
                        glassSection(title: "Инструменты") {
                            VStack(spacing: 12) {
                                Button(action: {
                                    HapticsService.shared.selection()
                                    showingFinderSheet = true
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "magnifyingglass.circle.fill")
                                            .foregroundColor(.uniNextSky)
                                            .font(.title3)
                                        Text("Свободные аудитории / Преподаватели")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)

                                Divider().opacity(0.25)

                                Button(action: {
                                    HapticsService.shared.selection()
                                    showingBellSheet = true
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "bell.circle.fill")
                                            .foregroundColor(.uniWindowAmber)
                                            .font(.title3)
                                        Text("Расписание звонков")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)

                                Divider().opacity(0.25)

                                Button(action: {
                                    HapticsService.shared.selection()
                                    showingDiffSheet = true
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                            .foregroundColor(viewModel.hasScheduleDiff ? .uniLiveEmerald : .secondary)
                                            .font(.title3)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Что изменилось в расписании")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundColor(viewModel.hasScheduleDiff ? .primary : .secondary)
                                            if !viewModel.hasScheduleDiff {
                                                Text("Пока нет зафиксированных изменений")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if viewModel.hasScheduleDiff {
                                            Image(systemName: "chevron.right")
                                                .font(.caption.bold())
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(!viewModel.hasScheduleDiff || repository.lastScheduleDiff == nil)
                            }
                        }

                        // 3. Поделиться расписанием (cardShare)
                        glassSection(title: "Поделиться расписанием") {
                            Button(action: {
                                HapticsService.shared.selection()
                                let data = viewModel.buildCurrentExportData()
                                exportTarget = SettingsExportTarget(
                                    day: data.day,
                                    week: data.week,
                                    targetName: data.targetName,
                                    isGroup: data.isGroup
                                )
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "square.and.arrow.up.circle.fill")
                                        .foregroundColor(.accentColor)
                                        .font(.title3)
                                    Text("День / Неделя — картинка или текст")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        // 4. Перезачёт и исключённые предметы (cardExcludedSubjects)
                        glassSection(title: "Перезачёт и исключённые предметы") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(viewModel.currentSelectionIsGroup
                                     ? viewModel.excludedSubjectsSummary
                                     : "Доступно при выборе учебной группы")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Button(action: {
                                    HapticsService.shared.selection()
                                    showingExcludedSheet = true
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                            .foregroundColor(viewModel.currentSelectionIsGroup ? .uniWindowAmber : .secondary)
                                            .font(.title3)
                                        Text("Настроить вычеркнутые предметы")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(viewModel.currentSelectionIsGroup ? .primary : .secondary)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(!viewModel.currentSelectionIsGroup)
                            }
                        }

                        // 5. Уведомления и таймер
                        glassSection(title: "Уведомления и таймер") {
                            VStack(spacing: 12) {
                                Toggle(isOn: $viewModel.liveLessonNotifEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Живое уведомление пары")
                                            .font(.subheadline.weight(.medium))
                                        Text("Этапы 45-5-45 и перемена для текущей пары")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Divider().opacity(0.25)

                                Toggle("Напоминание перед началом пары", isOn: $viewModel.remindersEnabled)
                                    .font(.subheadline.weight(.medium))

                                if viewModel.remindersEnabled {
                                    Divider().opacity(0.25)

                                    HStack {
                                        Text("Время напоминания")
                                            .font(.subheadline.weight(.medium))
                                        Spacer()
                                        Picker("Время напоминания", selection: $viewModel.reminderMinutesBefore) {
                                            Text("За 10 минут").tag(10)
                                            Text("За 15 минут").tag(15)
                                            Text("За 30 минут").tag(30)
                                        }
                                        .pickerStyle(.menu)
                                    }
                                }

                                Divider().opacity(0.25)

                                Toggle("Утренний дайджест в 07:30", isOn: $viewModel.morningDigestEnabled)
                                    .font(.subheadline.weight(.medium))
                            }
                        }

                        // 6. Оформление и семестр
                        glassSection(title: "Оформление и семестр", footer: viewModel.semesterDescription) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("Тема приложения", systemImage: "circle.lefthalf.filled")
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Picker("Тема приложения", selection: $viewModel.themeMode) {
                                        ForEach(ThemeMode.allCases) { mode in
                                            Text(mode.rawValue).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }

                                Divider().opacity(0.25)

                                Toggle(isOn: $viewModel.reducedTransparency) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Уменьшить прозрачность")
                                            .font(.subheadline.weight(.medium))
                                        Text("Снижает размытие и отключает анимацию фона")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Divider().opacity(0.25)

                                Picker(
                                    "Семестр",
                                    selection: Binding(
                                        get: { viewModel.selectedSemester },
                                        set: { viewModel.selectSemester($0) }
                                    )
                                ) {
                                    ForEach(SemesterType.allCases) { semester in
                                        Text(semester.shortName).tag(semester)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Text(viewModel.selectedSemesterShortLabel)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)

                                Divider().opacity(0.25)

                                DatePicker(
                                    "Начало семестра",
                                    selection: $viewModel.semesterStartDate,
                                    displayedComponents: [.date]
                                )
                                .font(.subheadline.weight(.medium))
                            }
                        }

                        // 7. Кэш и данные
                        glassSection(title: "Кэш и данные", footer: viewModel.cacheStatusMessage) {
                            VStack(spacing: 12) {
                                Button(action: {
                                    Task { await viewModel.forceRefresh() }
                                }) {
                                    HStack {
                                        Label("Обновить расписание с сайта", systemImage: "arrow.clockwise")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.uniNextSky)
                                        Spacer()
                                        if viewModel.isRefreshing {
                                            ProgressView()
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isRefreshing)

                                Divider().opacity(0.25)

                                Button(action: {
                                    viewModel.clearCache()
                                }) {
                                    HStack {
                                        Label("Сбросить кэш", systemImage: "arrow.counterclockwise")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.uniWindowAmber)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)

                                Divider().opacity(0.25)

                                Button(role: .destructive, action: {
                                    HapticsService.shared.impact(.medium)
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                        showingClearDataDialog = true
                                    }
                                }) {
                                    HStack {
                                        Label("Очистить данные", systemImage: "trash")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.uniRose)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // 8. О приложении
                        glassSection(title: "О приложении") {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(viewModel.aboutVersionText)
                                        .font(.headline.bold())
                                        .foregroundColor(.primary)

                                    Text(viewModel.lastUpdatedFormatted)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Divider().opacity(0.25)

                                HStack {
                                    Text("Университет")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("РГАТУ им. П.А. Соловьёва")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                Button(action: {
                                    HapticsService.shared.selection()
                                    if let url = URL(string: Constants.githubReleasesURL) {
                                        openURL(url)
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Что нового и релизы (GitHub)")
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.caption.bold())
                                    }
                                    .foregroundColor(.uniNextSky)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .liquidGlassCapsule(tint: .uniNextSky, reducedTransparency: viewModel.reducedTransparency)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                if showingClearDataDialog {
                    clearDataGlassDialog
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                        .zIndex(10)
                }
            }
            .preferredColorScheme(viewModel.themeMode.colorScheme)
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSelectionSheet) {
                SelectionView { name, isGroup in
                    viewModel.selectTarget(name: name, isGroup: isGroup)
                }
            }
            .sheet(isPresented: $showingFinderSheet) {
                RoomTeacherFinderSheet(
                    repository: .shared,
                    weekCalculator: WeekCalculator(semesterStartDate: viewModel.semesterStartDate),
                    initialSemester: viewModel.selectedSemester
                )
            }
            .sheet(isPresented: $showingDiffSheet) {
                if let diff = repository.lastScheduleDiff {
                    ScheduleDiffSheet(diff: diff) {
                        showingDiffSheet = false
                    }
                }
            }
            .sheet(isPresented: $showingBellSheet) {
                BellScheduleSheet(clockState: ScheduleClock.compute(for: Date(), scheduleLessons: []))
            }
            .sheet(item: $exportTarget) { target in
                ExportScheduleSheet(
                    daySchedule: target.day,
                    weekSchedule: target.week,
                    targetName: target.targetName,
                    isGroup: target.isGroup
                )
            }
            .sheet(isPresented: $showingExcludedSheet) {
                ExcludedSubjectsSheet(
                    groupName: viewModel.currentSelectionName,
                    allSubjects: viewModel.allSubjectsForCurrentGroup
                )
            }
        }
    }

    @ViewBuilder
    private func glassSection<Content: View>(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)

            content()
                .padding(14)
                .liquidGlassCard(cornerRadius: 18, state: .normal, reducedTransparency: viewModel.reducedTransparency)

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
            }
        }
    }

    private var clearDataGlassDialog: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showingClearDataDialog = false
                    }
                }

            VStack(spacing: 16) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 42))
                    .foregroundColor(.uniRose)

                VStack(spacing: 6) {
                    Text("Очистить данные")
                        .font(.headline.bold())
                        .foregroundColor(.primary)

                    Text("Удалить расписание и настройки?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    Button(action: {
                        HapticsService.shared.selection()
                        withAnimation(.easeOut(duration: 0.2)) {
                            showingClearDataDialog = false
                        }
                    }) {
                        Text("Отмена")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .liquidGlassCapsule(reducedTransparency: viewModel.reducedTransparency)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        viewModel.clearAllData()
                        withAnimation(.easeOut(duration: 0.2)) {
                            showingClearDataDialog = false
                        }
                    }) {
                        Text("Удалить")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.uniRose)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
            .frame(maxWidth: 320)
            .liquidGlassCard(cornerRadius: 24, state: .normal, reducedTransparency: viewModel.reducedTransparency)
            .padding(.horizontal, 24)
        }
    }
}
