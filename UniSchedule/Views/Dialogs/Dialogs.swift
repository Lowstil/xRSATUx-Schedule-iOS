import SwiftUI

public struct BellScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
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
            VStack(spacing: 16) {
                Picker("Тип дня", selection: $selectedDayType) {
                    Text("Будни (ПН–ПТ)").tag(1)
                    Text("Суббота (СБ)").tag(6)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                List {
                    ForEach(0..<times.count, id: \.self) { index in
                        let lessonNum = index + 1
                        let t = times[index]
                        let isCurrent = (clockState.currentLessonNumber == lessonNum)
                        
                        VStack(spacing: 8) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(isCurrent ? Color.accentColor : Color.secondary.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    
                                    Text("\(lessonNum)")
                                        .font(.subheadline.bold())
                                        .foregroundColor(isCurrent ? .white : .primary)
                                }
                                
                                Text("\(lessonNum) пара")
                                    .font(.headline)
                                    .foregroundColor(isCurrent ? .accentColor : .primary)
                                
                                Spacer()
                                
                                Text("\(t.start) – \(t.end)")
                                    .font(.system(.subheadline, design: .monospaced).bold())
                                    .foregroundColor(isCurrent ? .accentColor : .secondary)
                            }
                            
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
                            
                            // Highlight big break (after pair 2)
                            if lessonNum == 2 && selectedDayType == 1 {
                                HStack {
                                    Image(systemName: "cup.and.saucer.fill")
                                        .foregroundColor(.orange)
                                    Text("Большая перемена: 50 минут (11:50 – 12:40)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(isCurrent ? Color.accentColor.opacity(0.08) : Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Таблица звонков")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

public struct LessonNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    
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
            Form {
                Section(header: Text("Занятие")) {
                    Text(subjectName)
                        .font(.headline)
                    Text("\(lessonNumber) пара · \(dateString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Домашнее задание / Заметка")) {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 120)
                    
                    Toggle("Отмечено как выполнено", isOn: $isCompleted)
                }
                
                if existingNoteId != nil {
                    Section {
                        Button(role: .destructive, action: deleteNote) {
                            HStack {
                                Spacer()
                                Text("Удалить заметку")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Заметка к паре")
            .navigationBarTitleDisplayMode(.inline)
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

public struct ExcludedSubjectsSheet: View {
    @Environment(\.dismiss) private var dismiss
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
            List {
                Section(footer: Text("Отмеченные предметы будут отображаться зачёркнутыми с плашкой «Перезачёт», а таймеры и напоминания по ним отключатся.")) {
                    ForEach(allSubjects, id: \.self) { subject in
                        let isExcluded = excludedSet.contains(subject)
                        Button(action: {
                            toggleSubject(subject)
                        }) {
                            HStack {
                                Text(subject)
                                    .foregroundColor(.primary)
                                Spacer()
                                if isExcluded {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.orange)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Перезачёт (\(groupName))")
            .navigationBarTitleDisplayMode(.inline)
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
            VStack(alignment: .leading, spacing: 18) {
                // Header info
                VStack(alignment: .leading, spacing: 6) {
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
                }
                
                // Current status badge
                HStack(spacing: 8) {
                    Text("Текущий статус:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if item.isAttended {
                        Text(isFuture ? "🟢 Отмечено: Пойду" : "🟢 Отмечено: Посещено")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(8)
                    } else if item.isSkipped {
                        Text("🔴 Отмечено: Н-ка (пропуск)")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(8)
                    } else {
                        Text("⚪ Не отмечено")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(8)
                    }
                }
                
                Divider()
                
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
                    .background(Color.green.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.35), lineWidth: 1.5)
                    )
                    .cornerRadius(16)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.35), lineWidth: 1.5)
                    )
                    .cornerRadius(16)
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
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(20)
            .navigationTitle("Отметка пары")
            .navigationBarTitleDisplayMode(.inline)
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
    public let groupName: String
    
    @State private var report = AttendanceManager.AttendanceReport(overall: AttendanceManager.OverallAttendance(), subjects: [])
    private let repository = ScheduleRepository.shared
    
    public init(groupName: String) {
        self.groupName = groupName
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Header Subtitle
                    HStack {
                        Text("Группа: \(groupName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    
                    // Overall Attendance Card
                    VStack(spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Общая посещаемость")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.secondary)
                                
                                Text("\(report.overall.attendancePercent)%")
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundColor(percentColor(report.overall.attendancePercent))
                            }
                            
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                                    .frame(width: 64, height: 64)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(report.overall.attendancePercent) / 100.0)
                                    .stroke(percentColor(report.overall.attendancePercent), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 64, height: 64)
                            }
                        }
                        
                        // Summary Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(height: 10)
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(percentColor(report.overall.attendancePercent))
                                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(report.overall.attendancePercent) / 100.0)), height: 10)
                            }
                        }
                        .frame(height: 10)
                        
                        Text("Посещено: \(report.overall.attendedCount) из \(report.overall.totalPlanned) пар · \(AttendanceManager.formatSkips(report.overall.missedCount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(18)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Subjects Section
                    if report.subjects.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                                .padding(.top, 24)
                            Text("Данные по предметам отсутствуют")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("По предметам")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(report.subjects) { sa in
                                SubjectAttendanceRow(
                                    subject: sa,
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
            .navigationTitle("Моя посещаемость")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .onAppear {
                reloadReport()
            }
        }
    }
    
    private func reloadReport() {
        self.report = AttendanceManager.shared.calculateReport(groupName: groupName, repository: repository)
    }
    
    private func adjustSubject(_ subject: String, delta: Int) {
        repository.adjustManualSkips(group: groupName, subject: subject, delta: delta)
        reloadReport()
        HapticsService.shared.selection()
    }
    
    private func percentColor(_ percent: Int) -> Color {
        if percent >= 80 { return .green }
        if percent >= 60 { return .orange }
        return .red
    }
}

// MARK: - Subject Attendance Row Component
private struct SubjectAttendanceRow: View {
    let subject: AttendanceManager.SubjectAttendance
    let onMinus: () -> Void
    let onPlus: () -> Void
    
    private var percentColor: Color {
        if subject.attendancePercent >= 80 { return .green }
        if subject.attendancePercent >= 60 { return .orange }
        return .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(subject.subjectName)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Spacer()
                
                Text("\(subject.attendancePercent)%")
                    .font(.subheadline.bold())
                    .foregroundColor(percentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(percentColor.opacity(0.12))
                    .cornerRadius(6)
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(percentColor)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(subject.attendancePercent) / 100.0)), height: 6)
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("Посещено \(subject.attendedCount) из \(subject.totalPlanned) · \(AttendanceManager.formatSkips(subject.missedCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Stepper Buttons (+ / -)
                HStack(spacing: 8) {
                    Button(action: onMinus) {
                        Image(systemName: "minus")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onPlus) {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Circle())
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
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(16)
    }
}
