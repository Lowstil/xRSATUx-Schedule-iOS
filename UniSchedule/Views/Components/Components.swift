import SwiftUI

public struct LessonTypeBadge: View {
    public let type: String
    
    public init(type: String) {
        self.type = type
    }
    
    private var color: Color {
        switch type {
        case Constants.lessonTypeLecture:
            return .blue
        case Constants.lessonTypePractice:
            return .orange
        case Constants.lessonTypeLab:
            return .purple
        case Constants.lessonTypeOnlineLecture, Constants.lessonTypeOnlinePractice:
            return .teal
        case Constants.lessonTypeExam:
            return .red
        default:
            return .secondary
        }
    }
    
    public var body: some View {
        Text(type)
            .font(.caption2.bold())
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

public struct LiveTimerBadge: View {
    public let clockState: ScheduleClockState
    
    @State private var isPulsing = false
    
    public init(clockState: ScheduleClockState) {
        self.clockState = clockState
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isPulsing ? 1.3 : 0.9)
                    .opacity(isPulsing ? 1.0 : 0.5)
                    .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
                
                Text("Идёт сейчас · осталось \(clockState.minutesLeftInCurrent) мин")
                    .font(.caption.bold())
                    .foregroundColor(.green)
                
                if !clockState.stageStatusText.isEmpty {
                    Text("(\(clockState.stageStatusText))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .onAppear {
                isPulsing = true
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green)
                        .frame(width: geo.size.width * CGFloat(min(max(clockState.currentProgressPercent, 0.0), 1.0)), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

public struct SearchBarView: View {
    @Binding public var text: String
    public var placeholder: String = "Поиск группы или преподавателя..."
    
    public init(text: Binding<String>, placeholder: String = "Поиск группы или преподавателя...") {
        self._text = text
        self.placeholder = placeholder
    }
    
    public var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
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
        .padding(10)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}
