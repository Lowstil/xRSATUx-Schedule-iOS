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
    public let onTapTeacher: (String) -> Void
    public let onTapRoom: (String) -> Void
    public let onDeleteCustom: () -> Void
    
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var livePulse = false
    @State private var showDeleteCustomAlert = false
    
    public init(
        item: ScheduleItem,
        clockState: ScheduleClockState,
        isGroupView: Bool,
        date: Date = Date(),
        note: LessonNote? = nil,
        warningText: String? = nil,
        onOpenNote: @escaping () -> Void,
        onOpenAttendance: @escaping () -> Void = {},
        onToggleSkipped: @escaping () -> Void,
        onTapTeacher: @escaping (String) -> Void = { _ in },
        onTapRoom: @escaping (String) -> Void = { _ in },
        onDeleteCustom: @escaping () -> Void = {}
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
        self.onTapTeacher = onTapTeacher
        self.onTapRoom = onTapRoom
        self.onDeleteCustom = onDeleteCustom
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var isInactive: Bool {
        item.isCancelled || item.isSkipped || item.isExcluded
    }
    
    private var isCurrent: Bool {
        isToday && clockState.currentLessonNumber == item.lessonNumber && !isInactive
    }
    
    private var isNext: Bool {
        isToday && !isCurrent && clockState.nextLessonNumber == item.lessonNumber && !isInactive
    }
    
    private var cardState: GlassCardState {
        if isCurrent { return .live }
        if isNext { return .next }
        return .normal
    }
    
    private var isFuture: Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    }
    
    private var typeColor: Color {
        if item.isCustom {
            return customBadgeColor
        }
        return lessonTypeColor(for: item.lessonType)
    }
    
    private var customBadgeColor: Color {
        colorScheme == .dark ? Color(hex: "#A78BFA") : Color(hex: "#7C3AED")
    }
    
    private var canTapTeacher: Bool {
        isGroupView && !item.teacherName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: lesson number, time, state pills, type/custom & room
            HStack(alignment: .center, spacing: 6) {
                Text("\(item.lessonNumber) пара")
                    .font(.subheadline.bold())
                    .foregroundColor(isCurrent ? .uniLiveEmerald : (isNext ? .uniNextSky : .primary))
                
                Text("·")
                    .foregroundColor(.secondary)
                
                Text(item.timeLabel)
                    .font(.system(.subheadline, design: .monospaced).monospacedDigit())
                    .foregroundColor(.secondary)
                
                if isCurrent {
                    liveBadge
                } else if isNext {
                    nextBadge
                }
                
                Spacer(minLength: 4)
                
                if item.isCustom {
                    customBadge
                } else if !item.lessonType.isEmpty {
                    LessonTypeBadge(type: item.lessonType)
                }
                
                if !item.room.isEmpty {
                    Button(action: {
                        HapticsService.shared.selection()
                        onTapRoom(item.room)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: item.isOnline ? "video.fill" : "door.left.hand.open")
                                .font(.system(size: 9, weight: .semibold))
                            Text(item.room)
                                .font(.caption2.bold())
                                .lineLimit(1)
                        }
                        .foregroundColor(.primary.opacity(0.85))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Live or upcoming banner
            if isCurrent {
                LiveTimerBadge(clockState: clockState)
            } else if isNext && clockState.minutesUntilNext > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.caption)
                        .foregroundColor(.uniNextSky)
                    Text(clockState.isBreak
                         ? "Перемена · до начала \(clockState.minutesUntilNext) мин"
                         : "До начала пары · \(clockState.minutesUntilNext) мин")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundColor(.uniNextSky)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .liquidGlassCapsule(tint: .uniNextSky, reducedTransparency: reducedTransparency)
            }
            
            // Subject title
            Text(item.subjectName)
                .font(.headline)
                .foregroundColor(isInactive ? .secondary : .primary)
                .strikethrough(isInactive)
                .fixedSize(horizontal: false, vertical: true)
            
            // Teacher or Group
            if !item.isCustom || !item.teacherName.isEmpty || !item.groupName.isEmpty {
                teacherOrGroupRow
            }
            
            // Custom event note/comment
            if item.isCustom, let customComment = item.transferNote, !customComment.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble")
                        .font(.caption)
                        .foregroundColor(customBadgeColor)
                    Text(customComment)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Status badges
            if !item.isCustom {
                statusBadgesRow
            }
            
            // Attendance Warning Banner
            if !item.isCustom, let warning = warningText, !item.isCancelled, !item.isExcluded, !item.isSkipped {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(warning)
                        .font(.caption2.bold())
                }
                .foregroundColor(.uniAmber)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .liquidGlassCapsule(tint: .uniAmber, reducedTransparency: reducedTransparency)
            }
            
            // Note preview
            if let note = note {
                Button(action: onOpenNote) {
                    HStack(spacing: 7) {
                        Image(systemName: note.isCompleted ? "checkmark.circle.fill" : "note.text")
                            .foregroundColor(note.isCompleted ? .uniLiveEmerald : .uniNextSky)
                        
                        Text(note.noteText.isEmpty && note.imagePath != nil ? "Фотография" : note.noteText)
                            .font(.caption)
                            .foregroundColor(note.isCompleted ? .secondary : .primary)
                            .strikethrough(note.isCompleted)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if note.imagePath != nil {
                            Image(systemName: "photo")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
        .padding(.trailing, 14)
        .padding(.leading, 22)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(isInactive ? Color.secondary.opacity(0.4) : typeColor)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 10)
        }
        .liquidGlassCard(cornerRadius: 18, state: cardState, reducedTransparency: reducedTransparency)
        .opacity(isInactive ? 0.62 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenNote()
        }
        .onLongPressGesture {
            HapticsService.shared.impact(.medium)
            if item.isCustom {
                showDeleteCustomAlert = true
            } else {
                onOpenAttendance()
            }
        }
        .contextMenu {
            if item.isCustom {
                Button(action: onOpenNote) {
                    Label("Добавить заметку / ДЗ", systemImage: "square.and.pencil")
                }
                
                Button(role: .destructive, action: {
                    showDeleteCustomAlert = true
                }) {
                    Label("Удалить личное событие", systemImage: "trash")
                }
            } else {
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
        .alert("Удалить личное событие?", isPresented: $showDeleteCustomAlert) {
            Button("Удалить", role: .destructive) {
                onDeleteCustom()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Событие «\(item.subjectName)» будет удалено из расписания.")
        }
    }
    
    @ViewBuilder
    private var teacherOrGroupRow: some View {
        let labelText = isGroupView
            ? (item.teacherName.isEmpty ? "Преподаватель не указан" : item.teacherName)
            : item.groupName
        
        if canTapTeacher {
            Button(action: {
                HapticsService.shared.selection()
                onTapTeacher(item.teacherName)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(.uniNextSky)
                    
                    Text(labelText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.65))
                }
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 6) {
                Image(systemName: isGroupView ? "person.fill" : "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(labelText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }
    
    private var customBadge: some View {
        Text("Личное")
            .font(.caption2.bold())
            .foregroundColor(customBadgeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .liquidGlassCapsule(tint: customBadgeColor, reducedTransparency: reducedTransparency)
    }
    
    private var liveBadge: some View {
        let inkColor: Color = (colorScheme == .dark) ? .uniLiveDarkInk : .white
        return HStack(spacing: 4) {
            Circle()
                .fill(inkColor)
                .frame(width: 6, height: 6)
                .scaleEffect(livePulse ? 1.3 : 0.85)
                .opacity(livePulse ? 1.0 : 0.55)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: livePulse)
            Text("LIVE")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(inkColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.uniLiveEmerald))
        .shadow(color: Color.uniLiveEmerald.opacity(0.35), radius: 4, x: 0, y: 1)
        .onAppear { livePulse = true }
    }
    
    private var nextBadge: some View {
        Text("ДАЛЕЕ")
            .font(.system(size: 10, weight: .heavy))
            .foregroundColor(.uniNextSky)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .liquidGlassCapsule(tint: .uniNextSky, reducedTransparency: reducedTransparency)
    }
    
    @ViewBuilder
    private var statusBadgesRow: some View {
        if item.isCancelled {
            HStack(spacing: 5) {
                Image(systemName: "xmark.circle.fill")
                Text(item.transferNote ?? "Занятие отменено")
                    .font(.caption.bold())
            }
            .foregroundColor(.uniRose)
        } else if item.isMovedIn {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.swap")
                Text(item.transferNote ?? "Перенесено")
                    .font(.caption.bold())
            }
            .foregroundColor(.uniNextSky)
        } else if item.isExcluded {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.seal.fill")
                Text("Перезачёт")
                    .font(.caption.bold())
            }
            .foregroundColor(.uniPurple)
        } else if item.isSkipped {
            Text("🔴 Н-ка")
                .font(.caption.bold())
                .foregroundColor(.uniRose)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .liquidGlassCapsule(tint: .uniRose, reducedTransparency: reducedTransparency)
        } else if item.isAttended {
            Text(isFuture ? "✓ Пойду" : "✓ Посещено")
                .font(.caption.bold())
                .foregroundColor(.uniLiveEmerald)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .liquidGlassCapsule(tint: .uniLiveEmerald, reducedTransparency: reducedTransparency)
        }
    }
}

public struct NextLessonCardView: View {
    public let nextLesson: NextLesson
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false
    
    public init(nextLesson: NextLesson) {
        self.nextLesson = nextLesson
    }
    
    private var typeColor: Color {
        lessonTypeColor(for: nextLesson.lessonType)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption.bold())
                    Text("Ближайшее занятие")
                        .font(.caption.bold())
                }
                .foregroundColor(.uniNextSky)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .liquidGlassCapsule(tint: .uniNextSky, reducedTransparency: reducedTransparency)
                
                Spacer()
                
                Text(DateUtils.formatDisplayDateShort(nextLesson.date))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 6) {
                Text("\(nextLesson.lessonNumber) пара · \(nextLesson.timeStart)–\(nextLesson.timeEnd)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
                
                Spacer()
                
                LessonTypeBadge(type: nextLesson.lessonType)
                
                if !nextLesson.room.isEmpty {
                    Text(nextLesson.room)
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                }
            }
            
            Text(nextLesson.subjectName)
                .font(.headline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(nextLesson.teacherOrGroup)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 14)
        .padding(.trailing, 14)
        .padding(.leading, 22)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(typeColor)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 10)
        }
        .liquidGlassCard(cornerRadius: 18, state: .next, reducedTransparency: reducedTransparency)
    }
}
