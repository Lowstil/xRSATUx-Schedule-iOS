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
