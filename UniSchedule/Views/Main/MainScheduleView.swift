import SwiftUI

private struct NoteTarget: Identifiable {
    let id = UUID()
    let item: ScheduleItem
    let date: Date
}

private struct AttendanceTarget: Identifiable {
    let id = UUID()
    let item: ScheduleItem
    let date: Date
}

private struct FinderTarget: Identifiable {
    let id = UUID()
    let teacher: String?
    let buildingFilter: String?
}

private struct BuildingTarget: Identifiable {
    let id = UUID()
    let rawRoom: String
}

private struct CompareTarget: Identifiable {
    let id = UUID()
    let secondGroup: String?
}

private enum MoreAction {
    case customEvent
    case compare
    case homework
    case bells
    case diff
    case settings
}

public struct MainScheduleView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @ObservedObject private var repository = ScheduleRepository.shared
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false

    @State private var pagedIndex: Int? = 0
    @State private var isSyncingScrollFromVM = false

    @State private var showingSelectionSheet = false
    @State private var showingMoreSheet = false
    @State private var pendingMoreAction: MoreAction? = nil

    @State private var showingCustomEventSheet = false
    @State private var showingHomeworkHubSheet = false
    @State private var showingBellSheet = false
    @State private var showingAttendanceStatsSheet = false
    @State private var showingSettingsSheet = false
    @State private var showingManualDiffSheet = false
    @State private var showingNoDiffAlert = false
    @State private var showingTeacherAttendanceAlert = false

    @State private var compareTarget: CompareTarget? = nil
    @State private var finderTarget: FinderTarget? = nil
    @State private var buildingTarget: BuildingTarget? = nil
    @State private var pendingOpenFinderFromBuilding = false
    @State private var pendingBuildingFilter: String? = nil

    @State private var activeNoteTarget: NoteTarget? = nil
    @State private var attendanceTarget: AttendanceTarget? = nil

    public init() {}

    private var todayPillTitle: String {
        let now = Date()
        let dow = DateUtils.toScheduleDayOfWeek(date: now)
        let shortDay: String
        if dow >= 1 && dow <= Constants.dayNamesShort.count {
            shortDay = Constants.dayNamesShort[dow - 1]
        } else {
            shortDay = "ВС"
        }
        return "\(shortDay) · \(DateUtils.formatDisplayDateShort(now))"
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(
                    isLessonActive: viewModel.clockState.currentLessonNumber != nil,
                    reducedTransparency: reducedTransparency
                )

                VStack(spacing: 6) {
                    // Android 1:1 top bar: two-line target capsule on left + Today pill on right
                    topBar

                    // Updating / Error Banner
                    if repository.isUpdating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Загрузка актуального расписания с сайта...")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.uniNextSky)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .liquidGlassCapsule(tint: .uniNextSky, reducedTransparency: reducedTransparency)
                        .padding(.horizontal)
                    } else if let errorMsg = viewModel.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.uniWindowAmber)
                            Text(errorMsg)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Spacer()
                            Button("Повторить") {
                                Task { await viewModel.refresh() }
                            }
                            .font(.caption.bold())
                            .foregroundColor(.uniNextSky)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .liquidGlassCapsule(tint: .uniWindowAmber, reducedTransparency: reducedTransparency)
                        .padding(.horizontal)
                    }

                    // Favorites bar
                    FavoritesBarView(
                        favorites: repository.favorites,
                        currentTarget: viewModel.selectedName,
                        onSelect: { item in
                            viewModel.selectTarget(name: item.name, isGroup: item.type == .group)
                        },
                        onRemove: { item in
                            if repository.isFavorite(name: item.name, type: item.type) {
                                repository.toggleFavorite(name: item.name, type: item.type)
                            }
                        },
                        onCompare: { type, name in
                            if type == .group {
                                compareTarget = CompareTarget(secondGroup: name)
                            }
                        }
                    )

                    // Week & Day picker (always shown for active semester & week, including unpublished)
                    WeekDayPickerView(
                        activeSemester: viewModel.activeSemester,
                        weekNumber: viewModel.selectedWeekNumber,
                        isEven: viewModel.weekCalculator(for: viewModel.activeSemester).isEvenWeek(viewModel.selectedWeekNumber),
                        selectedDayOfWeek: viewModel.selectedDayOfWeek,
                        days: daysForWeek(semester: viewModel.activeSemester, week: viewModel.selectedWeekNumber),
                        onPreviousWeek: viewModel.previousWeek,
                        onNextWeek: viewModel.nextWeek,
                        onResetWeek: viewModel.resetToCurrentWeekAndDay,
                        onSelectDay: viewModel.selectDay
                    )

                    // Unified 216-page lazy horizontal pager (0..<108 fall, 108..<216 spring)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(0..<ScheduleViewModel.totalPages, id: \.self) { pageIdx in
                                pagerPage(for: pageIdx)
                                    .id(pageIdx)
                                    .containerRelativeFrame(.horizontal)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $pagedIndex)
                }

                // Top floating semester toast
                VStack {
                    SemesterToastPill(message: viewModel.semesterToastMessage)
                        .padding(.top, 54)
                    Spacer()
                }
                .allowsHitTesting(false)

                // Bottom floating Liquid Glass dock
                VStack {
                    Spacer()
                    FloatingGlassDockView(
                        pendingNotesCount: viewModel.pendingNotesCount,
                        onPairsTap: {
                            viewModel.jumpToToday()
                        },
                        onAttendanceTap: {
                            if viewModel.isGroup {
                                showingAttendanceStatsSheet = true
                            } else {
                                showingTeacherAttendanceAlert = true
                            }
                        },
                        onRoomsTap: {
                            finderTarget = FinderTarget(teacher: nil, buildingFilter: nil)
                        },
                        onMoreTap: {
                            showingMoreSheet = true
                        }
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                pagedIndex = viewModel.currentPageIndex
                let (sem, wk, _) = viewModel.semesterAndWeekAndDay(forPage: viewModel.currentPageIndex)
                DispatchQueue.main.async {
                    viewModel.preloadNeighborsIfNeeded(semester: sem, week: wk)
                }
            }
            .onChange(of: viewModel.currentPageIndex) { _, newPage in
                if pagedIndex != newPage {
                    isSyncingScrollFromVM = true
                    withAnimation(.easeInOut(duration: 0.25)) {
                        pagedIndex = newPage
                    }
                    DispatchQueue.main.async {
                        isSyncingScrollFromVM = false
                    }
                }
            }
            .onChange(of: pagedIndex) { _, newPage in
                guard let newPage, !isSyncingScrollFromVM else { return }
                if viewModel.currentPageIndex != newPage {
                    viewModel.currentPageIndex = newPage
                }
            }
            .alert("Посещаемость для групп", isPresented: $showingTeacherAttendanceAlert) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text("Статистика посещаемости «Н-ки» доступна только при просмотре расписания учебной группы.")
            }
            .alert("Изменений не обнаружено", isPresented: $showingNoDiffAlert) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text("После последнего обновления расписания изменений для «\(viewModel.selectedName)» не зафиксировано.")
            }
            .sheet(isPresented: $showingSelectionSheet) {
                SelectionView { name, isGroup in
                    viewModel.selectTarget(name: name, isGroup: isGroup)
                }
            }
            .sheet(isPresented: $showingMoreSheet, onDismiss: handlePendingMoreAction) {
                MoreActionsSheet(
                    pendingNotesCount: viewModel.pendingNotesCount,
                    isUpdating: repository.isUpdating,
                    hasScheduleDiff: repository.lastScheduleDiff?.isEmpty == false,
                    onCustomEvent: { pendingMoreAction = .customEvent },
                    onCompareGroups: { pendingMoreAction = .compare },
                    onHomeworkHub: { pendingMoreAction = .homework },
                    onBellSchedule: { pendingMoreAction = .bells },
                    onScheduleDiff: { pendingMoreAction = .diff },
                    onRefreshSchedule: {
                        Task { await viewModel.refresh() }
                    },
                    onSettings: { pendingMoreAction = .settings }
                )
            }
            .sheet(isPresented: $showingCustomEventSheet) {
                CustomEventSheet(
                    targetName: viewModel.selectedName,
                    isGroup: viewModel.isGroup,
                    onSaved: { event in
                        viewModel.addCustomEvent(event)
                    }
                )
            }
            .sheet(item: $compareTarget) { target in
                CompareScheduleSheet(
                    viewModel: viewModel,
                    initialSecondGroup: target.secondGroup
                )
            }
            .sheet(isPresented: $showingHomeworkHubSheet) {
                HomeworkHubSheet(onNavigateToDate: { date in
                    viewModel.navigateToDate(date)
                })
            }
            .sheet(isPresented: $showingBellSheet) {
                BellScheduleSheet(clockState: viewModel.clockState)
            }
            .sheet(isPresented: $showingAttendanceStatsSheet) {
                AttendanceStatisticsSheet(
                    groupName: viewModel.selectedName,
                    semester: viewModel.activeSemester
                )
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
            }
            .sheet(item: $buildingTarget, onDismiss: {
                if pendingOpenFinderFromBuilding {
                    pendingOpenFinderFromBuilding = false
                    let filter = pendingBuildingFilter
                    pendingBuildingFilter = nil
                    finderTarget = FinderTarget(teacher: nil, buildingFilter: filter)
                }
            }) { target in
                BuildingInfoSheet(
                    rawRoom: target.rawRoom,
                    onOpenFreeRooms: { buildingFilter in
                        pendingBuildingFilter = buildingFilter
                        pendingOpenFinderFromBuilding = true
                    }
                )
            }
            .sheet(item: $finderTarget) { target in
                RoomTeacherFinderSheet(
                    repository: .shared,
                    weekCalculator: viewModel.weekCalculator(for: viewModel.activeSemester),
                    initialSemester: viewModel.activeSemester,
                    initialTeacher: target.teacher,
                    initialBuildingFilter: target.buildingFilter
                )
            }
            .sheet(
                isPresented: $viewModel.showScheduleDiffSheet,
                onDismiss: { viewModel.dismissScheduleDiff() }
            ) {
                if let diff = viewModel.activeScheduleDiff {
                    ScheduleDiffSheet(diff: diff) {
                        viewModel.dismissScheduleDiff()
                    }
                }
            }
            .sheet(isPresented: $showingManualDiffSheet) {
                if let diff = repository.lastScheduleDiff {
                    ScheduleDiffSheet(diff: diff) {
                        showingManualDiffSheet = false
                    }
                }
            }
            .sheet(item: $attendanceTarget) { target in
                MarkLessonAttendanceSheet(
                    item: target.item,
                    date: target.date,
                    onMarkAttended: {
                        viewModel.markLessonAttended(item: target.item, date: target.date)
                    },
                    onMarkSkipped: {
                        viewModel.markLessonSkipped(item: target.item, date: target.date)
                    },
                    onReset: {
                        viewModel.clearLessonAttendance(item: target.item, date: target.date)
                    }
                )
                .presentationDetents([.fraction(0.58), .medium])
            }
            .sheet(item: $activeNoteTarget) { target in
                LessonNoteSheet(
                    dateString: DateUtils.isoDateFormatter.string(from: target.date),
                    lessonNumber: target.item.lessonNumber,
                    subjectName: target.item.subjectName
                )
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: {
                HapticsService.shared.selection()
                showingSelectionSheet = true
            }) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.selectedName.isEmpty ? "Выбрать" : viewModel.selectedName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(viewModel.isGroup ? "Учебная группа" : "Преподаватель")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .liquidGlassCapsule(reducedTransparency: reducedTransparency)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button(action: {
                viewModel.jumpToToday()
            }) {
                Text(todayPillTitle)
                    .font(.caption.bold().monospacedDigit())
                    .foregroundColor(.uniNextSky)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .liquidGlassCapsule(tint: .uniNextSky, reducedTransparency: reducedTransparency)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }

    // MARK: - Helpers & Pages

    private func handlePendingMoreAction() {
        guard let action = pendingMoreAction else { return }
        pendingMoreAction = nil

        switch action {
        case .customEvent:
            showingCustomEventSheet = true
        case .compare:
            compareTarget = CompareTarget(secondGroup: nil)
        case .homework:
            showingHomeworkHubSheet = true
        case .bells:
            showingBellSheet = true
        case .diff:
            if let diff = repository.lastScheduleDiff, !diff.isEmpty {
                showingManualDiffSheet = true
            } else {
                showingNoDiffAlert = true
            }
        case .settings:
            showingSettingsSheet = true
        }
    }

    private func daysForWeek(semester: SemesterType, week: Int) -> [DaySchedule] {
        if let cached = viewModel.weekSchedule(for: semester, week: week) {
            return cached.days
        }
        let calc = viewModel.weekCalculator(for: semester)
        let monday = calc.getMondayOfWeek(weekNumber: week)
            ?? DateUtils.mondayOfWeek(for: SemesterManager.loadSemesterStart(for: semester))
        return (1...6).map { dow in
            let date = DateUtils.dateForDayInWeek(monday: monday, dayOfWeek: dow)
            return DaySchedule(dayOfWeek: dow, date: date, lessons: [])
        }
    }

    private func notesSnapshot(for date: Date) -> [String: LessonNote] {
        let dateStr = DateUtils.isoDateFormatter.string(from: date)
        var snapshot: [String: LessonNote] = [:]
        for note in repository.notes where note.dateString == dateStr {
            snapshot["\(note.lessonNumber)#\(note.subjectName)"] = note
        }
        return snapshot
    }

    @ViewBuilder
    private func pagerPage(for pageIdx: Int) -> some View {
        let (sem, wk, dow) = viewModel.semesterAndWeekAndDay(forPage: pageIdx)

        Group {
            if !viewModel.isSemesterPublished(sem) {
                ScrollView {
                    VStack(spacing: 14) {
                        UnpublishedSemesterCardView(semester: sem) {
                            Task { await viewModel.refresh() }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                    .padding(.bottom, 96)
                }
                .refreshable {
                    await viewModel.refresh()
                }
            } else if let day = viewModel.weekSchedule(for: sem, week: wk)?.days.first(where: { $0.dayOfWeek == dow }) {
                let isToday = Calendar.current.isDateInToday(day.date)
                let isEmpty = day.isDayOff || day.lessons.isEmpty

                DayPageContentView(
                    day: day,
                    entries: isEmpty ? [] : viewModel.entries(for: day),
                    clockState: isToday ? viewModel.clockState : nil,
                    isGroupView: viewModel.isGroup,
                    warningsBySubject: viewModel.warningsBySubject,
                    notesSnapshot: notesSnapshot(for: day.date),
                    nextUpcomingLesson: isEmpty ? viewModel.nextUpcomingLesson : nil,
                    reducedTransparency: reducedTransparency,
                    onRefresh: { await viewModel.refresh() },
                    onOpenNote: { item in
                        activeNoteTarget = NoteTarget(item: item, date: day.date)
                    },
                    onOpenAttendance: { item in
                        attendanceTarget = AttendanceTarget(item: item, date: day.date)
                    },
                    onToggleSkipped: { item in
                        if item.isSkipped {
                            viewModel.clearLessonAttendance(item: item, date: day.date)
                        } else {
                            viewModel.markLessonSkipped(item: item, date: day.date)
                        }
                    },
                    onTapTeacher: { teacher in
                        finderTarget = FinderTarget(teacher: teacher, buildingFilter: nil)
                    },
                    onTapRoom: { room in
                        buildingTarget = BuildingTarget(rawRoom: room)
                    },
                    onDeleteCustom: { customId in
                        viewModel.deleteCustomEvent(id: customId)
                    }
                )
                .equatable()
            } else {
                VStack {
                    Spacer()
                    ProgressView("Загрузка расписания...")
                        .padding()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                viewModel.preloadNeighborsIfNeeded(semester: sem, week: wk)
            }
        }
    }
}

// MARK: - Equatable Day Page Content (prevents non-today re-renders on clock ticks)

private struct DayPageContentView: View, Equatable {
    let day: DaySchedule
    let entries: [DayScheduleEntry]
    let clockState: ScheduleClockState?
    let isGroupView: Bool
    let warningsBySubject: [String: String]
    let notesSnapshot: [String: LessonNote]
    let nextUpcomingLesson: NextLesson?
    let reducedTransparency: Bool

    let onRefresh: () async -> Void
    let onOpenNote: (ScheduleItem) -> Void
    let onOpenAttendance: (ScheduleItem) -> Void
    let onToggleSkipped: (ScheduleItem) -> Void
    let onTapTeacher: (String) -> Void
    let onTapRoom: (String) -> Void
    let onDeleteCustom: (UUID) -> Void

    static func == (lhs: DayPageContentView, rhs: DayPageContentView) -> Bool {
        lhs.day == rhs.day &&
        lhs.entries == rhs.entries &&
        lhs.clockState == rhs.clockState &&
        lhs.isGroupView == rhs.isGroupView &&
        lhs.warningsBySubject == rhs.warningsBySubject &&
        lhs.notesSnapshot == rhs.notesSnapshot &&
        lhs.nextUpcomingLesson == rhs.nextUpcomingLesson &&
        lhs.reducedTransparency == rhs.reducedTransparency
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if day.isDayOff {
                    emptyDayView(
                        icon: "sun.max.fill",
                        iconColor: .uniWindowAmber,
                        title: day.holidayName ?? "Выходной день",
                        subtitle: "Занятий нет — отличный день для отдыха!"
                    )
                } else if day.lessons.isEmpty {
                    emptyDayView(
                        icon: "tray",
                        iconColor: .secondary,
                        title: "В этот день пар нет",
                        subtitle: "Можно заняться своими проектами"
                    )
                } else {
                    ForEach(entries) { entry in
                        switch entry {
                        case .gap(let gap):
                            LessonWindowCardView(gap: gap, reducedTransparency: reducedTransparency)
                                .padding(.horizontal)

                        case .lesson(let item):
                            let note = notesSnapshot["\(item.lessonNumber)#\(item.subjectName)"]
                            let warning = warningsBySubject[item.subjectName]
                                ?? warningsBySubject[item.subjectName.trimmingCharacters(in: .whitespacesAndNewlines)]

                            LessonCardView(
                                item: item,
                                clockState: clockState,
                                isGroupView: isGroupView,
                                date: day.date,
                                note: note,
                                warningText: warning,
                                reducedTransparency: reducedTransparency,
                                onOpenNote: { onOpenNote(item) },
                                onOpenAttendance: { onOpenAttendance(item) },
                                onToggleSkipped: { onToggleSkipped(item) },
                                onTapTeacher: onTapTeacher,
                                onTapRoom: onTapRoom,
                                onDeleteCustom: {
                                    if let customId = item.customEventId {
                                        onDeleteCustom(customId)
                                    }
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 96)
        }
        .refreshable {
            await onRefresh()
        }
    }

    @ViewBuilder
    private func emptyDayView(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 38))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .liquidGlassCard(cornerRadius: 18, state: .normal, reducedTransparency: reducedTransparency)

            if let next = nextUpcomingLesson {
                NextLessonCardView(nextLesson: next)
            }
        }
        .padding(.horizontal)
    }
}
