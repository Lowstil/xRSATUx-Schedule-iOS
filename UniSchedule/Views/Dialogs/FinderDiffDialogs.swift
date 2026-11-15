import SwiftUI

// MARK: - Room & Teacher Finder Sheet

public struct RoomTeacherFinderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency: Bool = false

    public let repository: ScheduleRepository
    public let weekCalculator: WeekCalculator

    private enum FinderTab: Int, CaseIterable {
        case teacher = 0
        case freeRooms = 1

        var title: String {
            switch self {
            case .teacher: return "Где преподаватель?"
            case .freeRooms: return "Свободные аудитории"
            }
        }
    }

    private struct BuildingOption: Identifiable, Hashable {
        let id: String
        let title: String
        let filter: String?
    }

    private static let buildingOptions: [BuildingOption] = [
        BuildingOption(id: "all", title: "Все", filter: nil),
        BuildingOption(id: "G", title: "Главный (Г)", filter: "Г"),
        BuildingOption(id: "1", title: "1 корпус", filter: "1"),
        BuildingOption(id: "2", title: "2 корпус", filter: "2"),
        BuildingOption(id: "3", title: "3 корпус", filter: "3")
    ]

    @State private var selectedTab: FinderTab = .teacher
    @State private var searchQuery: String = ""
    @State private var selectedTeacher: String? = nil
    @State private var selectedBuildingFilter: String? = nil
    @State private var selectedSlot: Int

    public init(repository: ScheduleRepository = .shared, weekCalculator: WeekCalculator) {
        self.repository = repository
        self.weekCalculator = weekCalculator

        let clock = ScheduleClock.compute(for: Date(), scheduleLessons: [])
        let defaultSlot = clock.currentLessonNumber ?? clock.nextLessonNumber ?? 1
        _selectedSlot = State(initialValue: min(max(defaultSlot, 1), 6))
    }

    private var targetDate: Date {
        let now = Date()
        if DateUtils.toScheduleDayOfWeek(date: now) == 0 {
            return Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        }
        return now
    }

    private var targetDayOfWeek: Int {
        let dow = DateUtils.toScheduleDayOfWeek(date: targetDate)
        return (dow >= 1 && dow <= 6) ? dow : 1
    }

    private var targetWeekType: String {
        weekCalculator.getWeekType(for: targetDate) ?? weekCalculator.currentWeekType
    }

    private var targetDayName: String {
        let idx = targetDayOfWeek - 1
        guard idx >= 0 && idx < Constants.dayNamesFull.count else { return "" }
        return Constants.dayNamesFull[idx]
    }

    private var filteredTeachers: [String] {
        let all = repository.getAllTeacherNames()
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(reducedTransparency: reducedTransparency)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    Picker("Режим поиска", selection: $selectedTab) {
                        ForEach(FinderTab.allCases, id: \.self) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if selectedTab == .teacher {
                        teacherFinderContent
                    } else {
                        freeRoomsContent
                    }
                }
            }
            .navigationTitle("Поиск по расписанию")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    // MARK: - Tab 1: Teacher Finder

    private var teacherFinderContent: some View {
        VStack(spacing: 12) {
            // Search input
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Поиск преподавателя...", text: $searchQuery)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .liquidGlassCard(cornerRadius: 14, reducedTransparency: reducedTransparency)
            .padding(.horizontal)

            ScrollView {
                LazyVStack(spacing: 10) {
                    if let teacher = selectedTeacher {
                        selectedTeacherDetailCard(for: teacher)
                            .padding(.bottom, 4)
                    }

                    if filteredTeachers.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("Преподаватели не найдены")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)
                    } else {
                        ForEach(filteredTeachers, id: \.self) { teacher in
                            let isSelected = (selectedTeacher == teacher)
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTeacher = isSelected ? nil : teacher
                                }
                                HapticsService.shared.selection()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(isSelected ? .accentColor : .secondary)

                                    Text(teacher)
                                        .font(.subheadline.weight(isSelected ? .bold : .medium))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)

                                    Spacer()

                                    Image(systemName: isSelected ? "chevron.up" : "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                }
                                .padding(14)
                                .liquidGlassCard(
                                    cornerRadius: 16,
                                    state: isSelected ? .next : .normal,
                                    reducedTransparency: reducedTransparency
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func selectedTeacherDetailCard(for teacher: String) -> some View {
        let lessons = repository.getLessonsForTeacher(
            teacher,
            weekType: targetWeekType,
            dayOfWeek: targetDayOfWeek
        )
        let clock = ScheduleClock.compute(for: Date(), scheduleLessons: lessons)
        let weekLabel = targetWeekType == Constants.weekTypeEven ? "чётная" : "нечётная"

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(teacher)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(targetDayName) · \(weekLabel) неделя")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    withAnimation { selectedTeacher = nil }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Live / Next status summary
            teacherStatusBanner(lessons: lessons, clock: clock)

            if !lessons.isEmpty {
                Divider()
                    .opacity(0.35)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(lessons) { lesson in
                        let isCurrent = clock.currentLessonNumber == lesson.lessonNumber
                        let timeLabel = Constants.getLessonTimeLabel(
                            dayOfWeek: targetDayOfWeek,
                            lessonNumber: lesson.lessonNumber
                        )

                        HStack(alignment: .top, spacing: 10) {
                            Text("\(lesson.lessonNumber)")
                                .font(.caption.bold())
                                .foregroundColor(isCurrent ? .white : .primary)
                                .frame(width: 24, height: 24)
                                .background(isCurrent ? Color.green : Color.secondary.opacity(0.18))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(lesson.subjectName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)

                                    if !lesson.lessonType.isEmpty {
                                        Text(lesson.lessonType)
                                            .font(.caption2.bold())
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                                    }
                                }

                                HStack(spacing: 8) {
                                    if !timeLabel.isEmpty {
                                        Text(timeLabel)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }

                                    Text("· \(roomDisplay(for: lesson))")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.primary)

                                    if !lesson.groupName.isEmpty {
                                        Text("· \(lesson.groupName)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(isCurrent ? Color.green.opacity(0.10) : Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .padding(16)
        .liquidGlassCard(
            cornerRadius: 20,
            state: clock.currentLessonNumber != nil ? .live : .next,
            reducedTransparency: reducedTransparency
        )
    }

    @ViewBuilder
    private func teacherStatusBanner(lessons: [ScheduleItem], clock: ScheduleClockState) -> some View {
        if let currNum = clock.currentLessonNumber,
           let currLesson = lessons.first(where: { $0.lessonNumber == currNum }) {
            let groupPart = currLesson.groupName.isEmpty ? "" : " (\(currLesson.groupName))"
            Text("Сейчас (\(currNum) пара): \(roomDisplay(for: currLesson)) · \(currLesson.subjectName)\(groupPart)")
                .font(.caption.bold())
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlassCapsule(tint: .green, reducedTransparency: reducedTransparency)
        } else if let nextNum = clock.nextLessonNumber,
                  let nextLesson = lessons.first(where: { $0.lessonNumber == nextNum }) {
            let groupPart = nextLesson.groupName.isEmpty ? "" : " (\(nextLesson.groupName))"
            let waitPart = clock.minutesUntilNext >= 0 ? " через \(clock.minutesUntilNext) мин" : ""
            Text("Далее (\(nextNum) пара\(waitPart)): \(roomDisplay(for: nextLesson)) · \(nextLesson.subjectName)\(groupPart)")
                .font(.caption.bold())
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlassCapsule(tint: .blue, reducedTransparency: reducedTransparency)
        } else {
            let emptyText = lessons.isEmpty
                ? "На этот день пар нет"
                : "Текущих пар сейчас нет (всего на день: \(lessons.count))"
            Text(emptyText)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlassCapsule(reducedTransparency: reducedTransparency)
        }
    }

    private func roomDisplay(for item: ScheduleItem) -> String {
        if item.isOnline {
            return item.room.isEmpty ? "Онлайн" : "Онлайн (\(item.room))"
        }
        return item.room.isEmpty ? "ауд. не указана" : "ауд. \(item.room)"
    }

    // MARK: - Tab 2: Free Rooms

    private var freeRoomsContent: some View {
        let freeRooms = repository.getFreeRooms(
            weekType: targetWeekType,
            dayOfWeek: targetDayOfWeek,
            lessonNumber: selectedSlot,
            buildingFilter: selectedBuildingFilter
        )
        let weekLabel = targetWeekType == Constants.weekTypeEven ? "чётная" : "нечётная"

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Building filter chips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Корпус")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.buildingOptions) { option in
                                let isSelected = (selectedBuildingFilter == option.filter)
                                Button(action: {
                                    selectedBuildingFilter = option.filter
                                    HapticsService.shared.selection()
                                }) {
                                    Text(option.title)
                                        .font(.subheadline.weight(isSelected ? .bold : .medium))
                                        .foregroundColor(isSelected ? .accentColor : .primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .liquidGlassCapsule(
                                            tint: isSelected ? .accentColor : nil,
                                            reducedTransparency: reducedTransparency
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Lesson slot picker (1...6)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Пара")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        Spacer()

                        Text("\(targetDayName) · \(weekLabel) неделя")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        ForEach(1...6, id: \.self) { slot in
                            let isSelected = (selectedSlot == slot)
                            Button(action: {
                                selectedSlot = slot
                                HapticsService.shared.selection()
                            }) {
                                VStack(spacing: 2) {
                                    Text("\(slot)")
                                        .font(.headline.bold())
                                    Text("пара")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(isSelected ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.14))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    let slotTime = Constants.getLessonTimeLabel(dayOfWeek: targetDayOfWeek, lessonNumber: selectedSlot)
                    if !slotTime.isEmpty {
                        Text("Время \(selectedSlot) пары: \(slotTime)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
                .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)
                .padding(.horizontal)

                // Results header + count badge
                HStack {
                    Text("Свободные аудитории")
                        .font(.headline)

                    Spacer()

                    Text("Свободно: \(freeRooms.count)")
                        .font(.caption.bold())
                        .foregroundColor(freeRooms.isEmpty ? .secondary : .green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .liquidGlassCapsule(
                            tint: freeRooms.isEmpty ? nil : .green,
                            reducedTransparency: reducedTransparency
                        )
                }
                .padding(.horizontal)

                if freeRooms.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "door.left.hand.closed")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("Свободных аудиторий не найдено")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)
                    .padding(.horizontal)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 95), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(freeRooms, id: \.self) { room in
                            HStack(spacing: 6) {
                                Image(systemName: "door.left.hand.open")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text(room)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .liquidGlassCard(cornerRadius: 14, reducedTransparency: reducedTransparency)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Schedule Diff Sheet ("Что изменилось")

public struct ScheduleDiffSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency: Bool = false

    public let diff: ScheduleDiffResult
    public let onDismiss: () -> Void

    public init(diff: ScheduleDiffResult, onDismiss: @escaping () -> Void) {
        self.diff = diff
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(reducedTransparency: reducedTransparency)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            // Header Summary Card
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(diff.targetName)
                                            .font(.title3.bold())
                                            .foregroundColor(.primary)

                                        Text(diff.isGroup ? "Группа" : "Преподаватель")
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Text("\(diff.changes.count)")
                                        .font(.title3.bold())
                                        .foregroundColor(.accentColor)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .liquidGlassCapsule(
                                            tint: .accentColor,
                                            reducedTransparency: reducedTransparency
                                        )
                                }

                                if !diff.summaryText.isEmpty {
                                    Text(diff.summaryText)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(16)
                            .liquidGlassCard(cornerRadius: 20, reducedTransparency: reducedTransparency)

                            if diff.changes.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(.green)
                                    Text("Изменений не обнаружено")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)
                            } else {
                                ForEach(diff.changes) { change in
                                    ScheduleChangeCardView(
                                        change: change,
                                        isGroup: diff.isGroup,
                                        reducedTransparency: reducedTransparency
                                    )
                                }
                            }
                        }
                        .padding()
                    }

                    // Bottom primary acknowledge button
                    Button(action: handleDismiss) {
                        Text("Понятно")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Что изменилось")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть", action: handleDismiss)
                }
            }
        }
    }

    private func handleDismiss() {
        onDismiss()
        dismiss()
    }
}

private struct ScheduleChangeCardView: View {
    let change: ScheduleChange
    let isGroup: Bool
    let reducedTransparency: Bool

    private var accentColor: Color {
        switch change.kind {
        case .added: return .green
        case .removed: return .red
        case .roomChanged: return .orange
        case .teacherChanged: return .blue
        }
    }

    private var badgeSymbol: String {
        switch change.kind {
        case .added: return "+"
        case .removed: return "−"
        case .roomChanged: return "🚪"
        case .teacherChanged: return "👤"
        }
    }

    private var kindTitle: String {
        switch change.kind {
        case .added: return "Добавлена пара"
        case .removed: return "Удалена пара"
        case .roomChanged: return "Изменилась аудитория"
        case .teacherChanged: return isGroup ? "Изменился преподаватель" : "Изменилась группа"
        }
    }

    private var dayName: String {
        let idx = change.dayOfWeek - 1
        guard idx >= 0 && idx < Constants.dayNamesFull.count else {
            return "День \(change.dayOfWeek)"
        }
        return Constants.dayNamesFull[idx]
    }

    private var weekLabel: String {
        change.weekType.lowercased() == Constants.weekTypeEven ? "чётная" : "нечётная"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(badgeSymbol)
                    .font(.headline.bold())
                    .foregroundColor(accentColor)
                    .frame(width: 32, height: 32)
                    .liquidGlassCapsule(tint: accentColor, reducedTransparency: reducedTransparency)

                VStack(alignment: .leading, spacing: 2) {
                    Text(kindTitle)
                        .font(.caption.bold())
                        .foregroundColor(accentColor)

                    Text("\(dayName) (\(weekLabel)) · \(change.lessonNumber) пара")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !change.lessonType.isEmpty {
                    Text(change.lessonType)
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                }
            }

            Text(change.subjectName)
                .font(.subheadline.bold())
                .foregroundColor(.primary)

            if let detailText = formattedDetails {
                Text(detailText)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .liquidGlassCapsule(tint: accentColor, reducedTransparency: reducedTransparency)
            }
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)
    }

    private var formattedDetails: String? {
        let oldVal = change.oldValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let newVal = change.newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        switch change.kind {
        case .added:
            return newVal.isEmpty ? nil : newVal
        case .removed:
            return oldVal.isEmpty ? nil : "Было: \(oldVal)"
        case .roomChanged, .teacherChanged:
            if !oldVal.isEmpty && !newVal.isEmpty {
                return "\(oldVal) → \(newVal)"
            }
            if !newVal.isEmpty {
                return "Стало: \(newVal)"
            }
            if !oldVal.isEmpty {
                return "Было: \(oldVal)"
            }
            return nil
        }
    }
}

// MARK: - Export Schedule Sheet

private struct ExportSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

public struct ExportScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency: Bool = false

    public let daySchedule: DaySchedule?
    public let weekSchedule: WeekSchedule?
    public let targetName: String
    public let isGroup: Bool

    @State private var sharePayload: ExportSharePayload? = nil
    @State private var errorMessage: String? = nil

    public init(
        daySchedule: DaySchedule?,
        weekSchedule: WeekSchedule?,
        targetName: String,
        isGroup: Bool
    ) {
        self.daySchedule = daySchedule
        self.weekSchedule = weekSchedule
        self.targetName = targetName
        self.isGroup = isGroup
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(reducedTransparency: reducedTransparency)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(targetName)
                                .font(.title3.bold())
                                .foregroundColor(.primary)

                            Text("Выберите формат для отправки или сохранения")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)

                        ForEach(ExportMode.allCases) { mode in
                            let available = isModeAvailable(mode)
                            Button(action: {
                                performExport(mode)
                            }) {
                                HStack(spacing: 14) {
                                    Image(systemName: mode.systemImage)
                                        .font(.title3.weight(.semibold))
                                        .foregroundColor(available ? .accentColor : .secondary)
                                        .frame(width: 40, height: 40)
                                        .liquidGlassCapsule(
                                            tint: available ? .accentColor : nil,
                                            reducedTransparency: reducedTransparency
                                        )

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(mode.rawValue)
                                            .font(.subheadline.bold())
                                            .foregroundColor(available ? .primary : .secondary)

                                        Text(mode.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "square.and.arrow.up")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(available ? .accentColor : .secondary.opacity(0.5))
                                }
                                .padding(14)
                                .opacity(available ? 1.0 : 0.5)
                                .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)
                            }
                            .buttonStyle(.plain)
                            .disabled(!available)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption.weight(.medium))
                                .foregroundColor(.red)
                                .padding(12)
                                .liquidGlassCard(cornerRadius: 14, reducedTransparency: reducedTransparency)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Экспорт расписания")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            #if canImport(UIKit)
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
            #endif
        }
    }

    private func isModeAvailable(_ mode: ExportMode) -> Bool {
        mode.isWeek ? (weekSchedule != nil) : (daySchedule != nil)
    }

    @MainActor
    private func performExport(_ mode: ExportMode) {
        errorMessage = nil
        HapticsService.shared.selection()

        switch mode {
        case .todayText:
            guard let day = daySchedule else { return }
            let text = ScheduleExporter.formatDayAsText(day: day, targetName: targetName, isGroup: isGroup)
            sharePayload = ExportSharePayload(items: [text])

        case .weekText:
            guard let week = weekSchedule else { return }
            let text = ScheduleExporter.formatWeekAsText(week: week, targetName: targetName, isGroup: isGroup)
            sharePayload = ExportSharePayload(items: [text])

        case .todayImage:
            guard let day = daySchedule else { return }
            if let url = ScheduleExporter.renderDayImage(day: day, targetName: targetName, isGroup: isGroup) {
                sharePayload = ExportSharePayload(items: [url])
            } else {
                errorMessage = "Не удалось сформировать изображение расписания."
            }

        case .weekImage:
            guard let week = weekSchedule else { return }
            if let url = ScheduleExporter.renderWeekImage(week: week, targetName: targetName, isGroup: isGroup) {
                sharePayload = ExportSharePayload(items: [url])
            } else {
                errorMessage = "Не удалось сформировать изображение расписания."
            }
        }
    }
}
