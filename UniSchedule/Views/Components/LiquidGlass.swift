import SwiftUI

public enum GlassCardState {
    case normal
    case live
    case next
}

// MARK: - Ambient Backdrop

public struct AmbientBackdropView: View {
    public let isLessonActive: Bool
    public let reducedTransparency: Bool

    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    public init(isLessonActive: Bool = false, reducedTransparency: Bool = false) {
        self.isLessonActive = isLessonActive
        self.reducedTransparency = reducedTransparency
    }

    private var effectiveReduced: Bool {
        reducedTransparency || systemReduceTransparency
    }

    public var body: some View {
        ZStack {
            // Static GPU-rasterized multi-blob gradient + soft specular sheen (120 FPS)
            ZStack {
                Color.uniBackdropBase

                RadialGradient(
                    colors: [Color.uniBackdropBlob1.opacity(effectiveReduced ? 0.55 : 0.72), Color.clear],
                    center: UnitPoint(x: 0.18, y: 0.16),
                    startRadius: 10,
                    endRadius: 340
                )

                RadialGradient(
                    colors: [Color.uniBackdropBlob2.opacity(effectiveReduced ? 0.45 : 0.60), Color.clear],
                    center: UnitPoint(x: 0.86, y: 0.44),
                    startRadius: 10,
                    endRadius: 330
                )

                RadialGradient(
                    colors: [Color.uniBackdropBlob3.opacity(effectiveReduced ? 0.35 : 0.48), Color.clear],
                    center: UnitPoint(x: 0.35, y: 0.85),
                    startRadius: 10,
                    endRadius: 350
                )

                if !effectiveReduced {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.045 : 0.20),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.65, y: 0.36)
                    )
                }
            }
            .drawingGroup(opaque: true)

            // Smooth warm emerald-amber aura when a lesson is active
            RadialGradient(
                colors: [
                    Color.uniBackdropBlobWarm.opacity(isLessonActive ? 0.85 : 0.0),
                    Color.uniWindowAmber.opacity(isLessonActive ? (colorScheme == .dark ? 0.14 : 0.10) : 0.0),
                    Color.clear
                ],
                center: UnitPoint(x: 0.78, y: 0.18),
                startRadius: 20,
                endRadius: 360
            )
            .animation(.easeInOut(duration: 0.6), value: isLessonActive)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Circular Progress Ring

public struct CircularProgressRingView: View {
    public let progress: Double // 0.0...1.0
    public let color: Color
    public var lineWidth: CGFloat = 6
    public var size: CGFloat = 56
    public var centerText: String? = nil
    public var font: Font = .system(size: 13, weight: .bold)

    @State private var animatedProgress: Double = 0

    public init(
        progress: Double,
        color: Color,
        lineWidth: CGFloat = 6,
        size: CGFloat = 56,
        centerText: String? = nil,
        font: Font = .system(size: 13, weight: .bold)
    ) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
        self.centerText = centerText
        self.font = font
    }

    private var clampedProgress: Double {
        min(max(progress, 0.0), 1.0)
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.22), color.opacity(0.0)],
                        center: .center,
                        startRadius: size * 0.15,
                        endRadius: size * 0.62
                    )
                )
                .frame(width: size * 1.12, height: size * 1.12)

            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.82), color],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            if let centerText {
                Text(centerText)
                    .font(font.monospacedDigit())
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.42)) {
                animatedProgress = clampedProgress
            }
        }
        .onChange(of: clampedProgress) { _, newValue in
            withAnimation(.easeOut(duration: 0.42)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Lesson Window Card

public struct LessonWindowCardView: View {
    public let gap: LessonGap
    public var reducedTransparency: Bool = false

    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency

    public init(gap: LessonGap, reducedTransparency: Bool = false) {
        self.gap = gap
        self.reducedTransparency = reducedTransparency
    }

    private var useFallback: Bool {
        reducedTransparency || systemReduceTransparency
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        HStack(spacing: 10) {
            Text("☕ Окно · \(gap.formattedDuration)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.uniWindowAmber)

            Spacer()

            Text("\(gap.startTime) – \(gap.endTime)")
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            ZStack {
                shape.fill(useFallback ? Color.uniGlassSurfaceFallback : Color.uniGlassSurface)
                if !useFallback {
                    shape.fill(Color.uniWindowAmber.opacity(0.06))
                }
            }
        )
        .overlay(
            shape.strokeBorder(
                Color.uniWindowAmber.opacity(useFallback ? 0.35 : 0.28),
                style: StrokeStyle(lineWidth: 1, dash: [5, 4])
            )
        )
    }
}

// MARK: - Liquid Glass View Modifiers (Lightweight 120 FPS Surfaces)

private struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let state: GlassCardState
    let reducedTransparency: Bool

    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency

    private var effectiveReduced: Bool {
        reducedTransparency || systemReduceTransparency
    }

    private var stateTint: Color {
        switch state {
        case .normal:
            return .clear
        case .live:
            return .uniLiveEmerald
        case .next:
            return .uniNextSky
        }
    }

    private var strokeGradient: LinearGradient {
        switch state {
        case .normal:
            return LinearGradient(
                colors: [Color.uniGlassStrokeStart, Color.uniGlassStrokeMid, Color.uniGlassStrokeEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .live:
            return LinearGradient(
                colors: [
                    Color.uniLiveEmerald.opacity(0.88),
                    Color.uniGlassStrokeStart.opacity(0.55),
                    Color.uniLiveEmerald.opacity(0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .next:
            return LinearGradient(
                colors: [
                    Color.uniNextSky.opacity(0.85),
                    Color.uniGlassStrokeStart.opacity(0.50),
                    Color.uniNextSky.opacity(0.40)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return content
            .background(
                ZStack {
                    shape.fill(effectiveReduced ? Color.uniGlassSurfaceFallback : Color.uniGlassSurface)
                    if state != .normal {
                        shape.fill(stateTint.opacity(effectiveReduced ? 0.12 : 0.10))
                    }
                }
            )
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    strokeGradient,
                    lineWidth: state == .normal ? 1.0 : 1.5
                )
            )
    }
}

private struct LiquidGlassCapsuleModifier: ViewModifier {
    let tint: Color?
    let reducedTransparency: Bool

    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency

    private var effectiveReduced: Bool {
        reducedTransparency || systemReduceTransparency
    }

    func body(content: Content) -> some View {
        let shape = Capsule()

        return content
            .background(
                shape.fill(
                    effectiveReduced
                        ? (tint?.opacity(0.20) ?? Color.uniGlassSurfaceFallback)
                        : (tint?.opacity(0.16) ?? Color.uniGlassCapsule)
                )
            )
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            tint?.opacity(0.55) ?? Color.uniGlassStrokeStart,
                            tint?.opacity(0.20) ?? Color.uniGlassStrokeEnd
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
    }
}

public extension View {
    func liquidGlassCard(
        cornerRadius: CGFloat = 18,
        state: GlassCardState = .normal,
        reducedTransparency: Bool = false
    ) -> some View {
        modifier(LiquidGlassCardModifier(
            cornerRadius: cornerRadius,
            state: state,
            reducedTransparency: reducedTransparency
        ))
    }

    func liquidGlassCapsule(
        tint: Color? = nil,
        reducedTransparency: Bool = false
    ) -> some View {
        modifier(LiquidGlassCapsuleModifier(
            tint: tint,
            reducedTransparency: reducedTransparency
        ))
    }
}

// MARK: - Unpublished Semester Card

public struct UnpublishedSemesterCardView: View {
    public let semester: SemesterType
    public let onCheckNow: () -> Void

    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false

    public init(semester: SemesterType, onCheckNow: @escaping () -> Void) {
        self.semester = semester
        self.onCheckNow = onCheckNow
    }

    private var titleText: String {
        switch semester {
        case .spring:
            return "Расписание на весенний семестр ещё не опубликовано"
        case .fall:
            return "Расписание на осенний семестр ещё не опубликовано"
        }
    }

    private var subtitleText: String {
        switch semester {
        case .spring:
            return "Оно появится автоматически после 30 января, как только вуз выложит новый файл на сайте."
        case .fall:
            return "Оно появится автоматически после 25 августа, как только вуз выложит новый файл на сайте."
        }
    }

    public var body: some View {
        VStack(spacing: 14) {
            Text("📅")
                .font(.system(size: 46))

            Text(titleText)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text(subtitleText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                HapticsService.shared.selection()
                onCheckNow()
            }) {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.bold())
                    Text("Проверить сейчас")
                        .font(.subheadline.bold())
                }
                .foregroundColor(.uniNextSky)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .liquidGlassCapsule(tint: .uniNextSky, reducedTransparency: reducedTransparency)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .liquidGlassCard(cornerRadius: 22, state: .normal, reducedTransparency: reducedTransparency)
    }
}
