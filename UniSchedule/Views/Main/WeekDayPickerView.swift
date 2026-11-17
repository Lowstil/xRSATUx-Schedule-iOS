import SwiftUI

public struct WeekDayPickerView: View {
    public let activeSemester: SemesterType
    public let weekNumber: Int
    public let isEven: Bool
    public let selectedDayOfWeek: Int
    public let days: [DaySchedule]

    public let onPreviousWeek: () -> Void
    public let onNextWeek: () -> Void
    public let onResetWeek: () -> Void
    public let onSelectDay: (Int) -> Void

    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency

    public init(
        activeSemester: SemesterType = .fall,
        weekNumber: Int,
        isEven: Bool,
        selectedDayOfWeek: Int,
        days: [DaySchedule],
        onPreviousWeek: @escaping () -> Void,
        onNextWeek: @escaping () -> Void,
        onResetWeek: @escaping () -> Void,
        onSelectDay: @escaping (Int) -> Void
    ) {
        self.activeSemester = activeSemester
        self.weekNumber = weekNumber
        self.isEven = isEven
        self.selectedDayOfWeek = selectedDayOfWeek
        self.days = days
        self.onPreviousWeek = onPreviousWeek
        self.onNextWeek = onNextWeek
        self.onResetWeek = onResetWeek
        self.onSelectDay = onSelectDay
    }

    private var effectiveReduced: Bool {
        reducedTransparency || systemReduceTransparency
    }

    private var isAtFirstWeek: Bool {
        activeSemester == .fall && weekNumber <= 1
    }

    private var isAtLastWeek: Bool {
        activeSemester == .spring && weekNumber >= SemesterManager.totalWeeks
    }

    private var dateRangeLabel: String {
        guard let first = days.first?.date, let last = days.last?.date else { return "" }
        return "\(DateUtils.formatDisplayDateShort(first)) – \(DateUtils.formatDisplayDateShort(last))"
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Unified Android-style Glass week switcher card
            HStack(spacing: 6) {
                Button(action: {
                    HapticsService.shared.selection()
                    onPreviousWeek()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .opacity(isAtFirstWeek ? 0.3 : 1.0)
                        .frame(width: 36, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isAtFirstWeek)

                Spacer(minLength: 4)

                Button(action: {
                    HapticsService.shared.selection()
                    onResetWeek()
                }) {
                    VStack(spacing: 1.5) {
                        Text("\(activeSemester.shortName) · Неделя \(weekNumber) (\(isEven ? "Чётная" : "Нечётная"))")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        if !dateRangeLabel.isEmpty {
                            Text(dateRangeLabel)
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                Button(action: {
                    HapticsService.shared.selection()
                    onNextWeek()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .opacity(isAtLastWeek ? 0.3 : 1.0)
                        .frame(width: 36, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isAtLastWeek)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .liquidGlassCard(cornerRadius: 20, state: .normal, reducedTransparency: effectiveReduced)
            .padding(.horizontal)

            // Slim crisp weekday pills (Mon-Sat): short name + day number + tiny 4pt today dot
            HStack(spacing: 6) {
                ForEach(days) { day in
                    let isSelected = (day.dayOfWeek == selectedDayOfWeek)
                    let isToday = Calendar.current.isDateInToday(day.date)
                    let dayNum = Calendar.current.component(.day, from: day.date)

                    Button(action: {
                        HapticsService.shared.selection()
                        withAnimation(.easeInOut(duration: 0.18)) {
                            onSelectDay(day.dayOfWeek)
                        }
                    }) {
                        VStack(spacing: 3) {
                            Text(day.dayNameShort)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isSelected ? .white.opacity(0.92) : (isToday ? .uniNextSky : .secondary))

                            Text("\(dayNum)")
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundColor(isSelected ? .white : .primary)

                            Circle()
                                .fill(isToday ? (isSelected ? Color.white : Color.uniNextSky) : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(dayCapsuleBackground(isSelected: isSelected, isToday: isToday))
                        .overlay(dayCapsuleBorder(isSelected: isSelected, isToday: isToday))
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func dayCapsuleBackground(isSelected: Bool, isToday: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        if isSelected {
            shape.fill(
                LinearGradient(
                    colors: [Color.accentColor, Color.uniNextSky.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else if effectiveReduced {
            shape.fill(isToday ? Color.uniNextSky.opacity(0.16) : Color.uniGlassSurfaceFallback)
        } else {
            shape.fill(isToday ? Color.uniNextSky.opacity(0.14) : Color.uniGlassSurface)
        }
    }

    private func dayCapsuleBorder(isSelected: Bool, isToday: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
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
            lineWidth: isSelected || isToday ? 1.2 : 1.0
        )
    }
}
