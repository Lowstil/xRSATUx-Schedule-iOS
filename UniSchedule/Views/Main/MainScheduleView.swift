import SwiftUI

public struct MainScheduleView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    
    @State private var showingSelectionSheet = false
    @State private var showingBellSheet = false
    @State private var showingSettingsSheet = false
    @State private var activeNoteItem: ScheduleItem? = nil
    
    private let repository = ScheduleRepository.shared
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Favorites bar
                FavoritesBarView(
                    favorites: repository.favorites,
                    currentTarget: viewModel.selectedName,
                    onSelect: { item in
                        viewModel.selectTarget(name: item.name, isGroup: item.type == .group)
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
                
                Divider()
                    .padding(.top, 4)
                
                // Day Content
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let day = viewModel.currentDaySchedule {
                            // Smart relative day label header
                            if let rel = day.relativeLabel {
                                HStack {
                                    Text(rel)
                                        .font(.subheadline.bold())
                                        .foregroundColor(rel == "Сегодня" ? .blue : (rel == "Завтра" ? .orange : .purple))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background((rel == "Сегодня" ? Color.blue : (rel == "Завтра" ? Color.orange : Color.purple)).opacity(0.12))
                                        .cornerRadius(8)
                                    
                                    Spacer()
                                    
                                    Text("\(day.dayNameFull), \(DateUtils.formatDisplayDate(day.date))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                            
                            // Day off or holiday
                            if day.isDayOff {
                                VStack(spacing: 12) {
                                    Image(systemName: "sun.max.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.orange)
                                        .padding(.top, 16)
                                    
                                    Text(day.holidayName ?? "Выходной день")
                                        .font(.headline)
                                    
                                    Text("Занятий нет — отличный день для отдыха!")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if let next = viewModel.nextUpcomingLesson {
                                        NextLessonCardView(nextLesson: next)
                                            .padding(.top, 8)
                                    }
                                }
                                .padding()
                            } else if day.lessons.isEmpty {
                                // No lessons on this day
                                VStack(spacing: 12) {
                                    Image(systemName: "tray")
                                        .font(.system(size: 36))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 16)
                                    
                                    Text("В этот день пар нет")
                                        .font(.headline)
                                    
                                    if let next = viewModel.nextUpcomingLesson {
                                        NextLessonCardView(nextLesson: next)
                                            .padding(.top, 8)
                                    }
                                }
                                .padding()
                            } else {
                                // List of pairs
                                ForEach(day.lessons) { item in
                                    let note = repository.getNote(
                                        dateString: DateUtils.isoDateFormatter.string(from: day.date),
                                        lessonNumber: item.lessonNumber,
                                        subject: item.subjectName
                                    )
                                    
                                    LessonCardView(
                                        item: item,
                                        clockState: viewModel.clockState,
                                        isGroupView: viewModel.isGroup,
                                        note: note,
                                        onOpenNote: {
                                            activeNoteItem = item
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
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .navigationTitle(viewModel.selectedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button(action: { showingSelectionSheet = true }) {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingBellSheet = true }) {
                        Image(systemName: "bell.badge")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettingsSheet = true }) {
                        Image(systemName: "gearshape")
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
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
            }
            .sheet(item: $activeNoteItem) { item in
                if let day = viewModel.currentDaySchedule {
                    LessonNoteSheet(
                        dateString: DateUtils.isoDateFormatter.string(from: day.date),
                        lessonNumber: item.lessonNumber,
                        subjectName: item.subjectName
                    )
                }
            }
        }
    }
}
