import SwiftUI

public struct LessonCardView: View {
    public let item: ScheduleItem
    public let clockState: ScheduleClockState?
    public let isGroupView: Bool
    public let date: Date
    public let note: LessonNote?
    public let warningText: String?
    public let reducedTransparency: Bool
    public let onOpenNote: () -> Void
    public let onOpenAttendance: () -> Void
    public let onToggleSkipped: () -> Void
    public let onTapTeacher: (String) -> Void
    public let onTapRoom: (String) -> Void
    public let onDeleteCustom: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showDeleteCustomAlert = false

    public init(
        item: ScheduleItem,
        clockState: ScheduleClockState? = nil,
        isGroupView: Bool,
        date: Date = Date(),
        note: LessonNote? = nil,
        warningText: String? = nil,
        reducedTransparency: Bool = false,
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
        self.reducedTransparency = reducedTransparency
        self.onOpenNote = onOpenNote
        self.onOpenAttendance = onOpenAttendance
        self.onToggleSkipped = onToggleSkipped
        self.onTapTeacher = onTapTeacher
        self.onTapRoom = onTapRoom
        self.onDeleteCustom = onDeleteCustom
    }

    private var isToday: Bool {
        clockState != nil || Calendar.current.isDateInToday(date)
    }

    private var isInactive: Bool {
        item.isCancelled || item.isSkipped || item.isExcluded
    }

    private var isCurrent: Bool {
        guard let clockState else { return false }
        return isToday && clockState.currentLessonNumber == item.lessonNumber && !isInactive
    }

    private var isNext: Bool {
        guard let clockState else { return false }
        return isToday && !isCurrent && clockState.nextLessonNumber == item.lessonNumber && !isInactive
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

    private var resolvedTimes: (start: String, end: String) {
        let times = Constants.getLessonTimes(dayOfWeek: item.dayOfWeek)
        if item.lessonNumber >= 1 && item.lessonNumber <= times.count {
            return times[item.lessonNumber - 1]
        }
        let raw = item.timeLabel
        let normalized = raw
            .replacingOccurrences(of: " - ", with: "–")
            .replacingOccurrences(of: "-", with: "–")
        let parts = normalized
            .split(separator: "–", maxSplits: 1)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if parts.count == 2 {
            return (parts[0], parts[1])
        }
        return (raw, "")
    }

    public var body: some View {
        let times = resolvedTimes

        HStack(alignment: .top, spacing: 10) {
            // Left Time Column (52pt wide, centered)
            VStack(spacing: 5) {
                Text("\(item.lessonNumber)")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundColor(numberBadgeForeground)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(numberBadgeBackground)
                    )

                VStack(spacing: 0) {
                    Text(times.start)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundColor(.primary.opacity(0.88))

                    if !times.end.isEmpty {
                        Text("–")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(times.end)
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 52)

            // Right Content Column
            VStack(alignment: .leading, spacing: 6) {
                if isCurrent, let cs = clockState {
                    liveStateSection(clockState: cs)
                } else if isNext, let cs = clockState {
                    nextStateRow(clockState: cs)
                }

                Text(item.subjectName)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundColor(isInactive ? .secondary : .primary)
                    .strikethrough(isInactive)
                    .fixedSize(horizontal: false, vertical: true)

                compactInfoRow

                if item.isCustom, let customComment = item.transferNote, !customComment.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "text.bubble")
                            .font(.caption2)
                            .foregroundColor(customBadgeColor)
                        Text(customComment)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !item.isCustom {
                    statusBadgesRow
                }

                if !item.isCustom, let warning = warningText, !isInactive {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text(warning)
                            .font(.caption2.bold())
                    }
                    .foregroundColor(.uniAmber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .liquidGlassCapsule(tint: .uniAmber, reducedTransparency: reducedTransparency)
                }

                if let note = note {
                    Button(action: onOpenNote) {
                        HStack(spacing: 6) {
                            Image(systemName: note.isCompleted ? "checkmark.circle.fill" : "note.text")
                                .font(.caption)
                                .foregroundColor(note.isCompleted ? .uniLiveEmerald : .uniNextSky)

                            Text(note.noteText.isEmpty && note.imagePath != nil ? "Фотография" : note.noteText)
                                .font(.caption)
                                .foregroundColor(note.isCompleted ? .secondary : .primary)
                                .strikethrough(note.isCompleted)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            if note.imagePath != nil {
                                Image(systemName: "photo")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.trailing, 13)
        .padding(.leading, 16)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(isInactive ? Color.secondary.opacity(0.4) : typeColor)
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.leading, 7)
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

    // MARK: - Subviews

    private var numberBadgeBackground: Color {
        if isCurrent { return .uniLiveEmerald }
        if isNext { return Color.uniNextSky.opacity(0.18) }
        if isInactive { return Color.secondary.opacity(0.12) }
        return typeColor.opacity(0.15)
    }

    private var numberBadgeForeground: Color {
        if isCurrent { return .uniLiveDarkInk }
        if isNext { return .uniNextSky }
        if isInactive { return .secondary }
        return typeColor
    }

    @ViewBuilder
    private func liveStateSection(clockState: ScheduleClockState) -> some View {
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

                Text(liveStageText(clockState))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundColor(.uniLiveEmerald)
                    .lineLimit(1)
            }

            LessonSegmentsProgressBar(progress: clockState.currentProgressPercent)
        }
    }

    private func liveStageText(_ clockState: ScheduleClockState) -> String {
        let stage = clockState.stageStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stage.isEmpty && clockState.minutesLeftInCurrent >= 0 {
            return "\(stage) · ост. \(clockState.minutesLeftInCurrent) мин"
        }
        if !stage.isEmpty {
            return stage
        }
        if clockState.minutesLeftInCurrent >= 0 {
            return "осталось \(clockState.minutesLeftInCurrent) мин"
        }
        return "идёт сейчас"
    }

    @ViewBuilder
    private func nextStateRow(clockState: ScheduleClockState) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.uniNextSky)
                .frame(width: 6, height: 6)

            Text(clockState.minutesUntilNext >= 0
                 ? "ДАЛЕЕ · через \(clockState.minutesUntilNext) мин"
                 : "ДАЛЕЕ")
                .font(.caption2.bold().monospacedDigit())
                .foregroundColor(.uniNextSky)
        }
    }

    private var compactInfoRow: some View {
        let teacherOrGroup = (isGroupView ? item.teacherName : item.groupName)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return HStack(spacing: 6) {
            if item.isCustom {
                Text("Личное")
                    .font(.caption2.bold())
                    .foregroundColor(customBadgeColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .liquidGlassCapsule(tint: customBadgeColor, reducedTransparency: reducedTransparency)
                    .fixedSize()
            } else if !item.lessonType.isEmpty {
                LessonTypeBadge(type: item.lessonType)
                    .fixedSize()
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
                    .padding(.vertical, 2.5)
                    .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                }
                .buttonStyle(.plain)
                .fixedSize()
            }

            if !teacherOrGroup.isEmpty {
                if canTapTeacher {
                    Button(action: {
                        HapticsService.shared.selection()
                        onTapTeacher(item.teacherName)
                    }) {
                        Text(teacherOrGroup)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.uniNextSky)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(teacherOrGroup)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }

    @ViewBuilder
    private var statusBadgesRow: some View {
        if item.isCancelled {
            HStack(spacing: 5) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                Text(item.transferNote ?? "Занятие отменено")
                    .font(.caption2.bold())
            }
            .foregroundColor(.uniRose)
        } else if item.isMovedIn {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.caption2)
                Text(item.transferNote ?? "Перенесено")
                    .font(.caption2.bold())
            }
            .foregroundColor(.uniNextSky)
        } else if item.isExcluded {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
                Text("Перезачёт")
                    .font(.caption2.bold())
            }
            .foregroundColor(.uniPurple)
        } else if item.isSkipped {
            Text("🔴 Н-ка")
                .font(.caption2.bold())
                .foregroundColor(.uniRose)
                .padding(.horizontal, 8)
                .padding(.vertical, 2.5)
                .liquidGlassCapsule(tint: .uniRose, reducedTransparency: reducedTransparency)
        } else if item.isAttended {
            Text(isFuture ? "✓ Пойду" : "✓ Посещено")
                .font(.caption2.bold())
                .foregroundColor(.uniLiveEmerald)
                .padding(.horizontal, 8)
                .padding(.vertical, 2.5)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption.bold())
                    Text("Ближайшее занятие")
                        .font(.caption.bold())
                }
                .foregroundColor(.uniNextSky)
                .padding(.horizontal, 9)
                .padding(.vertical, 3.5)
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
                        .padding(.vertical, 2.5)
                        .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                }
            }

            Text(nextLesson.subjectName)
                .font(.headline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !nextLesson.teacherOrGroup.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(nextLesson.teacherOrGroup)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.trailing, 13)
        .padding(.leading, 18)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(typeColor)
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.leading, 8)
        }
        .liquidGlassCard(cornerRadius: 18, state: .next, reducedTransparency: reducedTransparency)
    }
}
