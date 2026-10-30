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
        VStack(spacing: 8) {
            // Week switcher row
            HStack {
                Button(action: onPreviousWeek) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.bold())
                        .padding(8)
                }
                .disabled(weekNumber <= 1)
                
                Spacer()
                
                Button(action: onResetWeek) {
                    VStack(spacing: 2) {
                        Text("Неделя \(weekNumber) (\(isEven ? "чётная" : "нечётная"))")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(monthRangeLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onNextWeek) {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.bold())
                        .padding(8)
                }
                .disabled(weekNumber >= SemesterManager.totalWeeks)
            }
            .padding(.horizontal)
            
            // Days horizontal tabs
            HStack(spacing: 6) {
                ForEach(days) { day in
                    let isSelected = (day.dayOfWeek == selectedDayOfWeek)
                    let isToday = Calendar.current.isDateInToday(day.date)
                    let dayNum = Calendar.current.component(.day, from: day.date)
                    
                    Button(action: {
                        onSelectDay(day.dayOfWeek)
                    }) {
                        VStack(spacing: 4) {
                            Text(day.dayNameShort)
                                .font(.caption2.bold())
                                .foregroundColor(isSelected ? .white : (isToday ? .blue : .secondary))
                            
                            Text("\(dayNum)")
                                .font(.subheadline.bold())
                                .foregroundColor(isSelected ? .white : .primary)
                            
                            // Indicator dot for today or lessons count
                            if isToday {
                                Circle()
                                    .fill(isSelected ? Color.white : Color.blue)
                                    .frame(width: 4, height: 4)
                            } else {
                                Text("\(day.lessons.count)")
                                    .font(.system(size: 9))
                                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? Color.accentColor : (isToday ? Color.blue.opacity(0.12) : Color(UIColor.secondarySystemBackground))
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 4)
    }
}
