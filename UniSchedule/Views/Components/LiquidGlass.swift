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
    
    private var shouldFreezeMotion: Bool {
        reducedTransparency || systemReduceTransparency || ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    public var body: some View {
        ZStack {
            Color.uniBackdropBase
            
            if shouldFreezeMotion {
                staticBackdrop
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    animatedBlobs(time: t)
                }
            }
            
            // Subtle warm emerald-amber aura when a lesson is active
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
            .animation(.easeInOut(duration: 0.75), value: isLessonActive)
            
            if !shouldFreezeMotion {
                specularOverlay
            }
        }
        .ignoresSafeArea()
    }
    
    private var staticBackdrop: some View {
        ZStack {
            RadialGradient(
                colors: [Color.uniBackdropBlob1.opacity(0.65), Color.clear],
                center: UnitPoint(x: 0.18, y: 0.16),
                startRadius: 10,
                endRadius: 340
            )
            RadialGradient(
                colors: [Color.uniBackdropBlob2.opacity(0.55), Color.clear],
                center: UnitPoint(x: 0.86, y: 0.42),
                startRadius: 10,
                endRadius: 320
            )
            RadialGradient(
                colors: [Color.uniBackdropBlob3.opacity(0.45), Color.clear],
                center: UnitPoint(x: 0.35, y: 0.85),
                startRadius: 10,
                endRadius: 340
            )
        }
    }
    
    private func animatedBlobs(time: TimeInterval) -> some View {
        // ~22s smooth organic loop matching Android AmbientBackdropView
        let p1 = time * (2.0 * .pi / 22.0)
        let p2 = time * (2.0 * .pi / 27.0) + 1.4
        let p3 = time * (2.0 * .pi / 19.0) + 3.1
        
        return ZStack {
            RadialGradient(
                colors: [Color.uniBackdropBlob1, Color.clear],
                center: UnitPoint(
                    x: 0.22 + 0.16 * cos(p1),
                    y: 0.18 + 0.12 * sin(p1 * 0.9)
                ),
                startRadius: 12,
                endRadius: 360
            )
            
            RadialGradient(
                colors: [Color.uniBackdropBlob2, Color.clear],
                center: UnitPoint(
                    x: 0.80 + 0.15 * sin(p2),
                    y: 0.46 + 0.16 * cos(p2 * 0.85)
                ),
                startRadius: 12,
                endRadius: 350
            )
            
            RadialGradient(
                colors: [Color.uniBackdropBlob3, Color.clear],
                center: UnitPoint(
                    x: 0.38 + 0.18 * cos(p3 * 0.8),
                    y: 0.82 + 0.12 * sin(p3)
                ),
                startRadius: 12,
                endRadius: 370
            )
        }
    }
    
    private var specularOverlay: some View {
        Canvas { context, size in
            // Subtle specular sheen + ~2% deterministic micro-grain
            let topSheen = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.35)
            context.fill(
                Path(topSheen),
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.045 : 0.20),
                        Color.clear
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width * 0.6, y: size.height * 0.35)
                )
            )
            
            let step: CGFloat = 18
            let grainColor = (colorScheme == .dark ? Color.white : Color.black).opacity(0.018)
            var y: CGFloat = 4
            var row = 0
            while y < size.height {
                var x: CGFloat = (row % 2 == 0) ? 4 : 13
                while x < size.width {
                    let hash = ((Int(x) * 73856093) ^ (Int(y) * 19349663)) & 3
                    if hash == 0 {
                        context.fill(
                            Path(CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                            with: .color(grainColor)
                        )
                    }
                    x += step
                }
                y += step
                row += 1
            }
        }
        .allowsHitTesting(false)
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
            // Subtle radial halo behind ring
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
            
            // Glowing track
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            // Progress arc
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
                .shadow(color: color.opacity(0.35), radius: 4, x: 0, y: 0)
            
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
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Text("☕ Окно · \(gap.formattedDuration)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.uniWindowAmber)
            }
            
            Spacer()
            
            Text("\(gap.startTime) – \(gap.endTime)")
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                if useFallback {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.uniGlassSurfaceFallback)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.uniWindowAmber.opacity(0.06))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    Color.uniWindowAmber.opacity(useFallback ? 0.35 : 0.28),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                )
        )
    }
}

// MARK: - Liquid Glass View Modifiers

private struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let state: GlassCardState
    let reducedTransparency: Bool
    
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    
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
    
    private var shadowColor: Color {
        switch state {
        case .normal:
            return Color.black.opacity(colorScheme == .dark ? 0.28 : 0.07)
        case .live:
            return Color.uniLiveEmerald.opacity(colorScheme == .dark ? 0.28 : 0.20)
        case .next:
            return Color.uniNextSky.opacity(colorScheme == .dark ? 0.26 : 0.18)
        }
    }
    
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        return content
            .background(
                ZStack {
                    if effectiveReduced {
                        shape.fill(Color.uniGlassSurfaceFallback)
                    } else {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(Color.uniGlassSurface)
                    }
                    
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
            .shadow(
                color: shadowColor,
                radius: state == .normal ? 10 : 14,
                x: 0,
                y: state == .normal ? 4 : 6
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
                ZStack {
                    if effectiveReduced {
                        shape.fill(tint?.opacity(0.20) ?? Color.uniGlassSurfaceFallback)
                    } else {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(tint?.opacity(0.16) ?? Color.uniGlassCapsule)
                    }
                }
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
