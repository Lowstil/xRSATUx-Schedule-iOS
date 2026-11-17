import SwiftUI

public struct LessonTypeBadge: View {
    public let type: String
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false

    public init(type: String) {
        self.type = type
    }

    private var color: Color {
        lessonTypeColor(for: type)
    }

    public var body: some View {
        if !type.isEmpty {
            Text(type)
                .font(.caption2.bold())
                .foregroundColor(color)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .liquidGlassCapsule(tint: color, reducedTransparency: reducedTransparency)
        }
    }
}

/// Sleek 3-segment 45 | 5 | 45 progress bar matching Android's 45-5-45 lesson timeline.
public struct LessonSegmentsProgressBar: View {
    public let progress: Double // 0.0 ... 1.0

    public init(progress: Double) {
        self.progress = progress
    }

    private var clamped: Double {
        min(max(progress, 0.0), 1.0)
    }

    public var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 3
            let usableWidth = max(0, geo.size.width - spacing * 2)
            let w1 = usableWidth * (45.0 / 95.0)
            let w2 = max(10, usableWidth * (5.0 / 95.0))
            let w3 = max(0, usableWidth - w1 - w2)

            let p1 = min(max(clamped / (45.0 / 95.0), 0.0), 1.0)
            let p2 = min(max((clamped - (45.0 / 95.0)) / (5.0 / 95.0), 0.0), 1.0)
            let p3 = min(max((clamped - (50.0 / 95.0)) / (45.0 / 95.0), 0.0), 1.0)

            HStack(spacing: spacing) {
                segmentBar(width: w1, fillRatio: p1, color: .uniLiveEmerald)
                segmentBar(width: w2, fillRatio: p2, color: .uniWindowAmber)
                segmentBar(width: w3, fillRatio: p3, color: .uniLiveEmerald)
            }
        }
        .frame(height: 4)
    }

    private func segmentBar(width: CGFloat, fillRatio: Double, color: Color) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(color.opacity(0.20))
                .frame(width: width, height: 4)

            if fillRatio > 0 {
                Capsule()
                    .fill(color)
                    .frame(width: max(3, width * CGFloat(fillRatio)), height: 4)
            }
        }
        .frame(width: width, height: 4)
    }
}

public struct LiveTimerBadge: View {
    public let clockState: ScheduleClockState

    public init(clockState: ScheduleClockState) {
        self.clockState = clockState
    }

    private var isLiveActive: Bool {
        clockState.currentLessonNumber != nil && clockState.minutesLeftInCurrent >= 0
    }

    private var stageLabel: String {
        let base = clockState.stageStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.isEmpty {
            return "\(base) · ост. \(clockState.minutesLeftInCurrent) мин"
        }
        return "осталось \(clockState.minutesLeftInCurrent) мин"
    }

    public var body: some View {
        if isLiveActive {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.uniLiveDarkInk)
                            .frame(width: 5, height: 5)
                        Text("LIVE")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.uniLiveDarkInk)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(Color.uniLiveEmerald))

                    Text(stageLabel)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundColor(.uniLiveEmerald)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }

                LessonSegmentsProgressBar(progress: clockState.currentProgressPercent)
            }
        }
    }
}

public struct SearchBarView: View {
    @Binding public var text: String
    public var placeholder: String = "Поиск группы или преподавателя..."
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false

    public init(text: Binding<String>, placeholder: String = "Поиск группы или преподавателя...") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            TextField(placeholder, text: $text)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .liquidGlassCard(cornerRadius: 14, state: .normal, reducedTransparency: reducedTransparency)
    }
}
