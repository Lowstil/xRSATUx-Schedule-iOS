import SwiftUI

public struct LessonCardView: View {
    public let item: ScheduleItem
    public let clockState: ScheduleClockState
    public let isGroupView: Bool
    public let date: Date
    public let note: LessonNote?
    public let warningText: String?
    public let onOpenNote: () -> Void
    public let onOpenAttendance: () -> Void
    public let onToggleSkipped: () -> Void
    
    public init(
        item: ScheduleItem,
        clockState: ScheduleClockState,
        isGroupView: Bool,
        date: Date = Date(),
        note: LessonNote? = nil,
        warningText: String? = nil,
        onOpenNote: @escaping () -> Void,
        onOpenAttendance: @escaping () -> Void = {},
        onToggleSkipped: @escaping () -> Void
    ) {
        self.item = item
        self.clockState = clockState
        self.isGroupView = isGroupView
        self.date = date
        self.note = note
        self.warningText = warningText
        self.onOpenNote = onOpenNote
        self.onOpenAttendance = onOpenAttendance
        self.onToggleSkipped = onToggleSkipped
    }
    
    private var isCurrent: Bool {
        clockState.currentLessonNumber == item.lessonNumber && !item.isCancelled && !item.isExcluded && !item.isSkipped
    }
    
    private var isNextInBreak: Bool {
        clockState.isBreak && clockState.nextLessonNumber == item.lessonNumber && !item.isCancelled
    }
    
    private var isFuture: Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: lesson number & time, badges
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text("\(item.lessonNumber) пара")
                        .font(.subheadline.bold())
                        .foregroundColor(isCurrent ? .accentColor : .primary)
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    Text(item.timeLabel)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                LessonTypeBadge(type: item.lessonType)
                
                if !item.room.isEmpty {
                    Text(item.room)
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                }
            }
            
            // Live banner
            if isCurrent {
                LiveTimerBadge(clockState: clockState)
            } else if isNextInBreak {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.orange)
                    Text("Следующая · перемена (до пары \(clockState.minutesUntilNext) мин)")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 2)
            }
            
            // Subject title
            Text(item.subjectName)
                .font(.headline)
                .foregroundColor(item.isCancelled || item.isSkipped || item.isExcluded ? .secondary : .primary)
                .strikethrough(item.isCancelled || item.isSkipped || item.isExcluded)
            
            // Subtitle: Teacher or Group
            HStack(spacing: 6) {
                Image(systemName: isGroupView ? "person.fill" : "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(isGroupView ? (item.teacherName.isEmpty ? "Преподаватель не указан" : item.teacherName) : item.groupName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Status flags (Cancelled, Moved, Excluded, Skipped, Attended)
            if item.isCancelled {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(item.transferNote ?? "Занятие отменено")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }
            } else if item.isMovedIn {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.swap")
                        .foregroundColor(.blue)
                    Text(item.transferNote ?? "Перенесено")
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                }
            } else if item.isExcluded {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.purple)
                    Text("Перезачёт")
                        .font(.caption.bold())
                        .foregroundColor(.purple)
                }
            } else if item.isSkipped {
                HStack(spacing: 5) {
                    Text("🔴 Н-ка")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.12))
                .cornerRadius(6)
            } else if item.isAttended {
                HStack(spacing: 5) {
                    Text(isFuture ? "✓ Пойду" : "✓ Посещено")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12))
                .cornerRadius(6)
            }
            
            // Attendance Warning Banner
            if let warning = warningText, !item.isCancelled, !item.isExcluded, !item.isSkipped {
                HStack(spacing: 6) {
                    Text(warning)
                        .font(.caption2.bold())
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }
            
            // Homework Note preview
            if let note = note {
                Button(action: onOpenNote) {
                    HStack(spacing: 6) {
                        Image(systemName: note.isCompleted ? "checkmark.circle.fill" : "note.text")
                            .foregroundColor(note.isCompleted ? .green : .accentColor)
                        
                        Text(note.noteText)
                            .font(.caption)
                            .foregroundColor(note.isCompleted ? .secondary : .primary)
                            .strikethrough(note.isCompleted)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .cardStyle(isActive: isCurrent)
        .opacity(item.isCancelled || item.isSkipped || item.isExcluded ? 0.6 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenNote()
        }
        .onLongPressGesture {
            onOpenAttendance()
        }
        .contextMenu {
            Button(action: onOpenAttendance) {
                Label("Отметить посещаемость", systemImage: "checkmark.circle.badge.questionmark")
            }
            
            Button(action: onOpenNote) {
                Label("Добавить заметку / ДЗ", systemImage: "square.and.pencil")
            }
            
            Button(action: onToggleSkipped) {
                Label(item.isSkipped ? "Сбросить Н-ку" : "Поставить Н-ку (Пропуск)", systemImage: "figure.walk.motion")
            }
        }
    }
}

public struct NextLessonCardView: View {
    public let nextLesson: NextLesson
    
    public init(nextLesson: NextLesson) {
        self.nextLesson = nextLesson
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.accentColor)
                Text("Ближайшее занятие")
                    .font(.caption.bold())
                    .foregroundColor(.accentColor)
                
                Spacer()
                
                Text(DateUtils.formatDisplayDateShort(nextLesson.date))
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(nextLesson.lessonNumber) пара · \(nextLesson.timeStart)–\(nextLesson.timeEnd)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                LessonTypeBadge(type: nextLesson.lessonType)
                
                if !nextLesson.room.isEmpty {
                    Text(nextLesson.room)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                }
            }
            
            Text(nextLesson.subjectName)
                .font(.headline)
            
            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(nextLesson.teacherOrGroup)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .cardStyle(isActive: false)
    }
}
