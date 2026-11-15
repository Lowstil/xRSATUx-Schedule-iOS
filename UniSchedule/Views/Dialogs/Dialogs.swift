import SwiftUI

// MARK: - Bell Schedule Sheet

public struct BellScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency: Bool = false
    @State private var selectedDayType: Int = 1 // 1=Будни, 6=Суббота

    private let clockState: ScheduleClockState

    public init(clockState: ScheduleClockState = ScheduleClockState()) {
        self.clockState = clockState
    }

    private var times: [(start: String, end: String)] {
        Constants.getLessonTimes(dayOfWeek: selectedDayType)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(
                    isLessonActive: clockState.currentLessonNumber != nil,
                    reducedTransparency: reducedTransparency
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    Picker("Тип дня", selection: $selectedDayType) {
                        Text("Будни (ПН–ПТ)").tag(1)
                        Text("Суббота (СБ)").tag(6)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(0..<times.count, id: \.self) { index in
                                let lessonNum = index + 1
                                let t = times[index]
                                let isCurrent = (clockState.currentLessonNumber == lessonNum)

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(isCurrent ? Color.green : Color.secondary.opacity(0.18))
                                                .frame(width: 34, height: 34)

                                            Text("\(lessonNum)")
                                                .font(.subheadline.bold())
                                                .foregroundColor(isCurrent ? .white : .primary)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(lessonNum) пара")
                                                .font(.headline)
                                                .foregroundColor(isCurrent ? .green : .primary)

                                            if isCurrent {
                                                HStack(spacing: 6) {
                                                    Circle()
                                                        .fill(Color.green)
                                                        .frame(width: 6, height: 6)
                                                    Text("Идёт прямо сейчас")
                                                        .font(.caption.bold())
                                                        .foregroundColor(.green)
                                                }
                                            }
                                        }

                                        Spacer()

                                        Text("\(t.start) – \(t.end)")
                                            .font(.system(.subheadline, design: .monospaced).bold())
                                            .foregroundColor(isCurrent ? .green : .secondary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .liquidGlassCapsule(
                                                tint: isCurrent ? .green : nil,
                                                reducedTransparency: reducedTransparency
                                            )
                                    }

                                    // Highlight big break (after pair 2)
                                    if lessonNum == 2 && selectedDayType == 1 {
                                        HStack(spacing: 6) {
                                            Image(systemName: "cup.and.saucer.fill")
                                                .foregroundColor(.orange)
                                            Text("Большая перемена: 50 минут (11:50 – 12:40)")
                                                .font(.caption.weight(.medium))
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .liquidGlassCapsule(tint: .orange, reducedTransparency: reducedTransparency)
                                    }
                                }
                                .padding(14)
                                .liquidGlassCard(
                                    cornerRadius: 18,
                                    state: isCurrent ? .live : .normal,
                                    reducedTransparency: reducedTransparency
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Таблица звонков")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Lesson Note Sheet

public struct LessonNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency: Bool = false

    public let dateString: String
    public let lessonNumber: Int
    public let subjectName: String

    @State private var noteText: String = ""
    @State private var isCompleted: Bool = false
    @State private var existingNoteId: UUID? = nil

    private let repository = ScheduleRepository.shared

    public init(dateString: String, lessonNumber: Int, subjectName: String) {
        self.dateString = dateString
        self.lessonNumber = lessonNumber
        self.subjectName = subjectName
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(reducedTransparency: reducedTransparency)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Lesson Info Card
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Занятие")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            Text(subjectName)
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text("\(lessonNumber) пара · \(dateString)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)

                        // Note Editor Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Домашнее задание / Заметка")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            TextEditor(text: $noteText)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 140)
                                .padding(10)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Toggle("Отмечено как выполнено", isOn: $isCompleted)
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)

                        if existingNoteId != nil {
                            Button(role: .destructive, action: deleteNote) {
                                HStack {
                                    Spacer()
                                    Label("Удалить заметку", systemImage: "trash")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                                .liquidGlassCard(cornerRadius: 16, reducedTransparency: reducedTransparency)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Заметка к паре")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveNote()
                        dismiss()
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let existing = repository.getNote(dateString: dateString, lessonNumber: lessonNumber, subject: subjectName) {
                    self.noteText = existing.noteText
                    self.isCompleted = existing.isCompleted
                    self.existingNoteId = existing.id
                }
            }
        }
    }

    private func saveNote() {
        let note = LessonNote(
            id: existingNoteId ?? UUID(),
            dateString: dateString,
            lessonNumber: lessonNumber,
            subjectName: subjectName,
            noteText: noteText.trimmingCharacters(in: .whitespacesAndNewlines),
            isCompleted: isCompleted
        )
        repository.saveNote(note)
        HapticsService.shared.notification(.success)
    }

    private func deleteNote() {
        if let id = existingNoteId {
            repository.deleteNote(id: id)
            HapticsService.shared.notification(.warning)
        }
        dismiss()
    }
}

// MARK: - Excluded Subjects Sheet

public struct ExcludedSubjectsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency: Bool = false

    public let groupName: String
    public let allSubjects: [String]

    @State private var excludedSet: Set<String> = []
    private let repository = ScheduleRepository.shared

    public init(groupName: String, allSubjects: [String]) {
        self.groupName = groupName
        self.allSubjects = Array(Set(allSubjects)).sorted()
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(reducedTransparency: reducedTransparency)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        Text("Отмеченные предметы будут отображаться зачёркнутыми с плашкой «Перезачёт», а таймеры и напоминания по ним отключатся.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .liquidGlassCard(cornerRadius: 16, reducedTransparency: reducedTransparency)

                        ForEach(allSubjects, id: \.self) { subject in
                            let isExcluded = excludedSet.contains(subject)
                            Button(action: {
                                toggleSubject(subject)
                            }) {
                                HStack(spacing: 12) {
                                    Text(subject)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)

                                    Spacer()

                                    Image(systemName: isExcluded ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundColor(isExcluded ? .orange : .secondary)
                                }
                                .padding(14)
                                .liquidGlassCard(cornerRadius: 16, reducedTransparency: reducedTransparency)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Перезачёт (\(groupName))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .onAppear {
                self.excludedSet = repository.getExcludedSubjects(for: groupName)
            }
        }
    }

    private func toggleSubject(_ subject: String) {
        repository.toggleExcludedSubject(group: groupName, subject: subject)
        if excludedSet.contains(subject) {
            excludedSet.remove(subject)
        } else {
            excludedSet.insert(subject)
        }
        HapticsService.shared.selection()
    }
}

// MARK: - Mark Lesson Attendance Dialog ("Посетил / Н-ка")

public struct MarkLessonAttendanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency: Bool = false

    public let item: ScheduleItem
    public let date: Date
    public let onMarkAttended: () -> Void
    public let onMarkSkipped: () -> Void
    public let onReset: () -> Void

    public init(
        item: ScheduleItem,
        date: Date,
        onMarkAttended: @escaping () -> Void,
        onMarkSkipped: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        self.item = item
        self.date = date
        self.onMarkAttended = onMarkAttended
        self.onMarkSkipped = onMarkSkipped
        self.onReset = onReset
    }

    private var isFuture: Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(reducedTransparency: reducedTransparency)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header info card
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.subjectName)
                                .font(.title3.bold())
                                .foregroundColor(.primary)

                            let roomStr = item.room.isEmpty ? "" : " · ауд. \(item.room)"
                            Text("\(item.lessonNumber) пара · \(item.timeLabel)\(roomStr)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(DateUtils.formatDisplayDate(date))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                Text("Статус:")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)

                                if item.isAttended {
                                    Text(isFuture ? "🟢 Отмечено: Пойду" : "🟢 Отмечено: Посещено")
                                        .font(.caption.bold())
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .liquidGlassCapsule(tint: .green, reducedTransparency: reducedTransparency)
                                } else if item.isSkipped {
                                    Text("🔴 Отмечено: Н-ка (пропуск)")
                                        .font(.caption.bold())
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .liquidGlassCapsule(tint: .red, reducedTransparency: reducedTransparency)
                                } else {
                                    Text("⚪ Не отмечено")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                                }
                            }
                            .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 20, reducedTransparency: reducedTransparency)

                        // Button 1: Посетил / Пойду
                        Button(action: {
                            onMarkAttended()
                            dismiss()
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 42, height: 42)
                                    Image(systemName: "checkmark")
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(isFuture ? "Пойду на пару" : "Посетил пару")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                    Text("Отметить пару как посещенную (в зачёт)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .liquidGlassCard(cornerRadius: 18, state: .live, reducedTransparency: reducedTransparency)
                        }
                        .buttonStyle(.plain)

                        // Button 2: Поставить Н-ку (Пропуск)
                        Button(action: {
                            onMarkSkipped()
                            dismiss()
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 42, height: 42)
                                    Text("Н")
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Поставить Н-ку (Пропуск)")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    Text("Отметить пропуск (напоминания будут отключены)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)
                        }
                        .buttonStyle(.plain)

                        // Button 3: Сбросить отметку (if marked)
                        if item.isAttended || item.isSkipped {
                            Button(action: {
                                onReset()
                                dismiss()
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Сбросить отметку")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                                .liquidGlassCard(cornerRadius: 16, reducedTransparency: reducedTransparency)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Отметка пары")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Attendance Statistics Dialog ("Моя посещаемость")

public struct AttendanceStatisticsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency: Bool = false

    public let groupName: String

    @State private var report = AttendanceManager.AttendanceReport(
        overall: AttendanceManager.OverallAttendance(),
        subjects: []
    )
    @State private var skipLimitPercent: Int = AttendanceManager.shared.skipLimitPercent

    private let repository = ScheduleRepository.shared

    public init(groupName: String) {
        self.groupName = groupName
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(reducedTransparency: reducedTransparency)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Header Subtitle
                        HStack {
                            Text("Группа: \(groupName)")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Лимит: \(skipLimitPercent)%")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                        }
                        .padding(.horizontal)
                        .padding(.top, 6)

                        // Hero Overall Attendance Card
                        heroSummaryCard
                            .padding(.horizontal)

                        // Subjects Section
                        if report.subjects.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "chart.bar.doc.horizontal")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 18)
                                Text("Данные по предметам отсутствуют")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .liquidGlassCard(cornerRadius: 20, reducedTransparency: reducedTransparency)
                            .padding(.horizontal)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("По предметам")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(report.subjects) { sa in
                                    SubjectAttendanceRow(
                                        subject: sa,
                                        limitPercent: skipLimitPercent,
                                        reducedTransparency: reducedTransparency,
                                        onMinus: {
                                            adjustSubject(sa.subjectName, delta: -1)
                                        },
                                        onPlus: {
                                            adjustSubject(sa.subjectName, delta: 1)
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Моя посещаемость")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .onAppear {
                skipLimitPercent = AttendanceManager.shared.skipLimitPercent
                reloadReport()
            }
            .onChange(of: skipLimitPercent) { _, newValue in
                AttendanceManager.shared.skipLimitPercent = newValue
                HapticsService.shared.selection()
                reloadReport()
            }
        }
    }

    private var heroSummaryCard: some View {
        let overall = report.overall
        let color = healthColor(overall.budgetHealth)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Общая посещаемость")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)

                    Text(healthTitle(overall.budgetHealth))
                        .font(.caption.bold())
                        .foregroundColor(color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .liquidGlassCapsule(tint: color, reducedTransparency: reducedTransparency)

                    Text(
                        AttendanceManager.formatBudgetStatus(
                            missed: overall.missedCount,
                            planned: overall.totalPlanned,
                            limitPct: skipLimitPercent
                        )
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                }

                Spacer()

                CircularProgressRingView(
                    progress: Double(overall.attendancePercent) / 100.0,
                    color: color,
                    lineWidth: 8,
                    size: 76,
                    centerText: "\(overall.attendancePercent)%",
                    font: .system(size: 16, weight: .bold)
                )
            }

            Divider()
                .opacity(0.4)

            HStack {
                Text("Посещено: \(AttendanceManager.formatLessonsCount(overall.attendedCount)) из \(AttendanceManager.formatLessonsCount(overall.totalPlanned))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(AttendanceManager.formatSkips(overall.missedCount)) (\(overall.skipPercent)%)")
                    .font(.caption.bold())
                    .foregroundColor(overall.missedCount > 0 ? color : .secondary)
            }

            // Segmented skip-limit selector 20% / 25% / 30%
            VStack(alignment: .leading, spacing: 6) {
                Text("Порог допустимых пропусков")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Picker("Лимит пропусков", selection: $skipLimitPercent) {
                    ForEach(AttendanceManager.validSkipLimits, id: \.self) { pct in
                        Text("\(pct)%").tag(pct)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(18)
        .liquidGlassCard(cornerRadius: 22, reducedTransparency: reducedTransparency)
    }

    private func reloadReport() {
        self.report = AttendanceManager.shared.calculateReport(groupName: groupName, repository: repository)
    }

    private func adjustSubject(_ subject: String, delta: Int) {
        repository.adjustManualSkips(group: groupName, subject: subject, delta: delta)
        reloadReport()
        HapticsService.shared.selection()
    }
}

private func healthColor(_ health: BudgetHealth) -> Color {
    switch health {
    case .safe: return .green
    case .warning: return .orange
    case .exceeded: return .red
    }
}

private func healthTitle(_ health: BudgetHealth) -> String {
    switch health {
    case .safe: return "В норме"
    case .warning: return "Близко к лимиту"
    case .exceeded: return "Лимит превышен"
    }
}

// MARK: - Subject Attendance Row Component

private struct SubjectAttendanceRow: View {
    let subject: AttendanceManager.SubjectAttendance
    let limitPercent: Int
    let reducedTransparency: Bool
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        let color = healthColor(subject.budgetHealth)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                CircularProgressRingView(
                    progress: Double(subject.attendancePercent) / 100.0,
                    color: color,
                    lineWidth: 5,
                    size: 48,
                    centerText: "\(subject.attendancePercent)%",
                    font: .system(size: 11, weight: .bold)
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(subject.subjectName)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text("Пропуски: \(subject.skipPercent)%")
                            .font(.caption2.bold())
                            .foregroundColor(color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .liquidGlassCapsule(tint: color, reducedTransparency: reducedTransparency)

                        Text(
                            AttendanceManager.formatBudgetStatus(
                                missed: subject.missedCount,
                                planned: subject.totalPlanned,
                                limitPct: limitPercent
                            )
                        )
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(color)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .liquidGlassCapsule(tint: color, reducedTransparency: reducedTransparency)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack {
                Text("Посещено \(AttendanceManager.formatLessonsCount(subject.attendedCount)) из \(subject.totalPlanned) · \(AttendanceManager.formatSkips(subject.missedCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Stepper Buttons (- / +)
                HStack(spacing: 8) {
                    Button(action: onMinus) {
                        Image(systemName: "minus")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                    }
                    .buttonStyle(.plain)

                    Button(action: onPlus) {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Warning Badge: >= 3 skips
            if subject.hasWarning {
                HStack(spacing: 6) {
                    Text("🟡 Внимание: уже \(AttendanceManager.formatSkips(subject.missedCount)), пора ходить!")
                        .font(.caption2.bold())
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .liquidGlassCapsule(tint: .orange, reducedTransparency: reducedTransparency)
            }
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)
    }
}
