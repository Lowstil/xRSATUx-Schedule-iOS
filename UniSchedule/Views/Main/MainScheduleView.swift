import SwiftUI

public struct MainScheduleView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @ObservedObject private var repository = ScheduleRepository.shared
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false
    
    @State private var showingSelectionSheet = false
    @State private var showingBellSheet = false
    @State private var showingAttendanceStatsSheet = false
    @State private var showingSettingsSheet = false
    @State private var showingFinderSheet = false
    @State private var showingExportSheet = false
    @State private var showingManualDiffSheet = false
    @State private var activeNoteTarget: (item: ScheduleItem, date: Date)? = nil
    @State private var attendanceTarget: (item: ScheduleItem, date: Date)? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(
                    isLessonActive: viewModel.clockState.currentLessonNumber != nil,
                    reducedTransparency: reducedTransparency
                )
                
                VStack(spacing: 6) {
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
                        }
                    )
                    
                    // Week & Day picker
                    if let week = viewModel.weekSchedule {
                        WeekDayPickerView(
                            weekNumber: week.weekNumber,
                            isEven: week.isEven,
                            selectedDayOfWeek: viewModel.selectedDayOfWeek,
                            days: week.days,
                            onPreviousWeek: viewModel.previousWeek,
                            onNextWeek: viewModel.nextWeek,
                            onResetWeek: viewModel.resetToCurrentWeekAndDay,
                            onSelectDay: viewModel.selectDay
                        )
                    }
                    
                    // Horizontal swipeable 6-day pager (Mon-Sat) synced with WeekDayPickerView
                    if !viewModel.weekDays.isEmpty {
                        TabView(selection: $viewModel.selectedDayOfWeek) {
                            ForEach(viewModel.weekDays) { day in
                                dayPage(for: day)
                                    .tag(day.dayOfWeek)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedDayOfWeek)
                    } else {
                        Spacer()
                        ProgressView("Загрузка расписания...")
                            .padding()
                        Spacer()
                    }
                }
            }
            .navigationTitle(viewModel.selectedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button(action: { showingSelectionSheet = true }) {
                        HStack(spacing: 6) {
                            Text(viewModel.selectedName)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button(action: { showingBellSheet = true }) {
                            Image(systemName: "bell.badge")
                        }
                        
                        if viewModel.isGroup {
                            Button(action: { showingAttendanceStatsSheet = true }) {
                                Image(systemName: "chart.bar.xaxis")
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 10) {
                        Menu {
                            Button(action: { showingFinderSheet = true }) {
                                Label("Найти преподавателя / аудиторию", systemImage: "magnifyingglass")
                            }
                            
                            Button(action: { showingExportSheet = true }) {
                                Label("Экспорт расписания", systemImage: "square.and.arrow.up")
                            }
                            
                            if repository.lastScheduleDiff?.isEmpty == false {
                                Button(action: { showingManualDiffSheet = true }) {
                                    Label("Что изменилось", systemImage: "arrow.triangle.2.circlepath")
                                }
                            }
                            
                            Divider()
                            
                            Button(action: {
                                Task { await viewModel.refresh() }
                            }) {
                                Label("Обновить с сайта", systemImage: "arrow.clockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        
                        Button(action: { showingSettingsSheet = true }) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSelectionSheet) {
                SelectionView { name, isGroup in
                    viewModel.selectTarget(name: name, isGroup: isGroup)
                }
            }
            .sheet(isPresented: $showingBellSheet) {
                BellScheduleSheet(clockState: viewModel.clockState)
            }
            .sheet(isPresented: $showingAttendanceStatsSheet) {
                AttendanceStatisticsSheet(groupName: viewModel.selectedName)
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
            }
            .sheet(isPresented: $showingFinderSheet) {
                RoomTeacherFinderSheet(
                    repository: .shared,
                    weekCalculator: viewModel.weekCalculator
                )
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportScheduleSheet(
                    daySchedule: viewModel.currentDaySchedule,
                    weekSchedule: viewModel.weekSchedule,
                    targetName: viewModel.selectedName,
                    isGroup: viewModel.isGroup
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
            .sheet(isPresented: Binding(
                get: { attendanceTarget != nil },
                set: { if !$0 { attendanceTarget = nil } }
            )) {
                if let target = attendanceTarget {
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
            }
            .sheet(isPresented: Binding(
                get: { activeNoteTarget != nil },
                set: { if !$0 { activeNoteTarget = nil } }
            )) {
                if let target = activeNoteTarget {
                    LessonNoteSheet(
                        dateString: DateUtils.isoDateFormatter.string(from: target.date),
                        lessonNumber: target.item.lessonNumber,
                        subjectName: target.item.subjectName
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private func dayPage(for day: DaySchedule) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Relative day & full date header
                HStack {
                    if let rel = day.relativeLabel {
                        let badgeColor: Color = rel == "Сегодня"
                            ? .uniNextSky
                            : (rel == "Завтра" ? .uniWindowAmber : .uniPurple)
                        Text(rel)
                            .font(.subheadline.bold())
                            .foregroundColor(badgeColor)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 4)
                            .liquidGlassCapsule(tint: badgeColor, reducedTransparency: reducedTransparency)
                    }
                    
                    Spacer()
                    
                    Text("\(day.dayNameFull), \(DateUtils.formatDisplayDate(day.date))")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
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
                    ForEach(viewModel.entries(for: day)) { entry in
                        switch entry {
                        case .gap(let gap):
                            LessonWindowCardView(gap: gap, reducedTransparency: reducedTransparency)
                                .padding(.horizontal)
                        case .lesson(let item):
                            let note = repository.getNote(
                                dateString: DateUtils.isoDateFormatter.string(from: day.date),
                                lessonNumber: item.lessonNumber,
                                subject: item.subjectName
                            )
                            let warning = viewModel.getWarningForSubject(item.subjectName)
                            
                            LessonCardView(
                                item: item,
                                clockState: viewModel.clockState,
                                isGroupView: viewModel.isGroup,
                                date: day.date,
                                note: note,
                                warningText: warning,
                                onOpenNote: {
                                    activeNoteTarget = (item: item, date: day.date)
                                },
                                onOpenAttendance: {
                                    attendanceTarget = (item: item, date: day.date)
                                },
                                onToggleSkipped: {
                                    viewModel.toggleSkippedLesson(item: item)
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 28)
        }
        .refreshable {
            await viewModel.refresh()
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
            
            if let next = viewModel.nextUpcomingLesson {
                NextLessonCardView(nextLesson: next)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
}
