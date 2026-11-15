import SwiftUI

public struct WeekDayPickerView: View {
    public let weekNumber: Int
    public let isEven: Bool
    public let selectedDayOfWeek: Int
    public let days: [DaySchedule]
    
    public let onPreviousWeek: () -> Void
    public let onNextWeek: () -> Void
    public let onResetWeek: () -> Void
    public let onSelectDay: (Int) -> Void
    
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false
    
    public init(
        weekNumber: Int,
        isEven: Bool,
        selectedDayOfWeek: Int,
        days: [DaySchedule],
        onPreviousWeek: @escaping () -> Void,
        onNextWeek: @escaping () -> Void,
        onResetWeek: @escaping () -> Void,
        onSelectDay: @escaping (Int) -> Void
    ) {
        self.weekNumber = weekNumber
        self.isEven = isEven
        self.selectedDayOfWeek = selectedDayOfWeek
        self.days = days
        self.onPreviousWeek = onPreviousWeek
        self.onNextWeek = onNextWeek
        self.onResetWeek = onResetWeek
        self.onSelectDay = onSelectDay
    }
    
    private var monthRangeLabel: String {
        guard let first = days.first?.date, let last = days.last?.date else { return "" }
        return DateUtils.formatMonthRangeRu(start: first, end: last)
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            // Week switcher row
            HStack(spacing: 10) {
                Button(action: {
                    HapticsService.shared.selection()
                    onPreviousWeek()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.bold())
                        .foregroundColor(weekNumber <= 1 ? .secondary.opacity(0.4) : .primary)
                        .frame(width: 34, height: 34)
                        .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                }
                .disabled(weekNumber <= 1)
                
                Spacer()
                
                Button(action: {
                    HapticsService.shared.selection()
                    onResetWeek()
                }) {
                    VStack(spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Неделя \(weekNumber)")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            
                            Text(isEven ? "чётная" : "нечётная")
                                .font(.caption2.bold())
                                .foregroundColor(isEven ? .uniNextSky : .uniPurple)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .liquidGlassCapsule(
                                    tint: isEven ? .uniNextSky : .uniPurple,
                                    reducedTransparency: reducedTransparency
                                )
                        }
                        
                        if !monthRangeLabel.isEmpty {
                            Text(monthRangeLabel)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    HapticsService.shared.selection()
                    onNextWeek()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.bold())
                        .foregroundColor(weekNumber >= SemesterManager.totalWeeks ? .secondary.opacity(0.4) : .primary)
                        .frame(width: 34, height: 34)
                        .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                }
                .disabled(weekNumber >= SemesterManager.totalWeeks)
            }
            .padding(.horizontal)
            
            // Days horizontal capsules (Mon-Sat)
            HStack(spacing: 7) {
                ForEach(days) { day in
                    let isSelected = (day.dayOfWeek == selectedDayOfWeek)
                    let isToday = Calendar.current.isDateInToday(day.date)
                    let dayNum = Calendar.current.component(.day, from: day.date)
                    
                    Button(action: {
                        HapticsService.shared.selection()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            onSelectDay(day.dayOfWeek)
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(day.dayNameShort)
                                .font(.caption2.bold())
                                .foregroundColor(isSelected ? .white.opacity(0.92) : (isToday ? .uniNextSky : .secondary))
                            
                            Text("\(dayNum)")
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundColor(isSelected ? .white : .primary)
                            
                            if isToday {
                                Circle()
                                    .fill(isSelected ? Color.white : Color.uniNextSky)
                                    .frame(width: 5, height: 5)
                            } else {
                                Text("\(day.lessons.count)")
                                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(dayCapsuleBackground(isSelected: isSelected, isToday: isToday))
                        .overlay(dayCapsuleBorder(isSelected: isSelected, isToday: isToday))
                        .shadow(
                            color: isSelected ? Color.accentColor.opacity(0.30) : Color.clear,
                            radius: isSelected ? 8 : 0,
                            x: 0,
                            y: isSelected ? 4 : 0
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func dayCapsuleBackground(isSelected: Bool, isToday: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
        if isSelected {
            shape.fill(
                LinearGradient(
                    colors: [Color.accentColor, Color.uniNextSky.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else if reducedTransparency {
            shape.fill(isToday ? Color.uniNextSky.opacity(0.16) : Color.uniGlassSurfaceFallback)
        } else {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(isToday ? Color.uniNextSky.opacity(0.14) : Color.uniGlassSurface)
            }
        }
    }
    
    private func dayCapsuleBorder(isSelected: Bool, isToday: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
        return shape.strokeBorder(
            LinearGradient(
                colors: isSelected
                    ? [Color.white.opacity(0.65), Color.white.opacity(0.20)]
                    : (isToday
                       ? [Color.uniNextSky.opacity(0.75), Color.uniNextSky.opacity(0.25)]
                       : [Color.uniGlassStrokeStart, Color.uniGlassStrokeEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: isSelected || isToday ? 1.3 : 1.0
        )
    }
}
