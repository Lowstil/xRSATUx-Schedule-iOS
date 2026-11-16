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
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .liquidGlassCapsule(tint: color, reducedTransparency: reducedTransparency)
        }
    }
}

public struct LiveTimerBadge: View {
    public let clockState: ScheduleClockState
    
    @State private var isPulsing = false
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false
    
    public init(clockState: ScheduleClockState) {
        self.clockState = clockState
    }
    
    private var isLiveActive: Bool {
        clockState.currentLessonNumber != nil && clockState.minutesLeftInCurrent >= 0
    }
    
    public var body: some View {
        if isLiveActive {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color.uniLiveEmerald)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isPulsing ? 1.32 : 0.88)
                        .opacity(isPulsing ? 1.0 : 0.45)
                        .animation(
                            Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: isPulsing
                        )
                    
                    Text("Идёт сейчас · осталось \(clockState.minutesLeftInCurrent) мин")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundColor(.uniLiveEmerald)
                    
                    if !clockState.stageStatusText.isEmpty {
                        Text("· \(clockState.stageStatusText)")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .liquidGlassCapsule(tint: .uniLiveEmerald, reducedTransparency: reducedTransparency)
                .onAppear {
                    isPulsing = true
                }
                .onDisappear {
                    isPulsing = false
                }
                
                // Progress bar
                GeometryReader { geo in
                    let fraction = CGFloat(min(max(clockState.currentProgressPercent, 0.0), 1.0))
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.uniLiveEmerald.opacity(0.18))
                            .frame(height: 5)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.uniLiveEmerald, Color.uniNextSky],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * fraction), height: 5)
                            .shadow(color: Color.uniLiveEmerald.opacity(0.4), radius: 3, x: 0, y: 0)
                    }
                }
                .frame(height: 5)
            }
            .padding(.vertical, 2)
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
