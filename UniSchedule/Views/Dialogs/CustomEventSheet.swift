import SwiftUI

public struct CustomEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency: Bool = false

    public let targetName: String
    public let isGroup: Bool
    public let onSaved: (CustomEvent) -> Void

    @State private var isRecurring: Bool = false
    @State private var selectedDate: Date = DateUtils.initialScheduleDate(Date()) ?? Date()
    @State private var selectedDayOfWeek: Int
    @State private var selectedWeekFilter: CustomEventWeekFilter = .both
    @State private var selectedLessonNumber: Int = 1

    @State private var subjectName: String = ""
    @State private var room: String = ""
    @State private var teacherName: String = ""
    @State private var note: String = ""
    @State private var showTitleError: Bool = false

    public init(targetName: String, isGroup: Bool, onSaved: @escaping (CustomEvent) -> Void) {
        self.targetName = targetName
        self.isGroup = isGroup
        self.onSaved = onSaved

        let dow = DateUtils.toScheduleDayOfWeek(date: Date())
        _selectedDayOfWeek = State(initialValue: (dow >= 1 && dow <= 6) ? dow : 1)
    }

    private var targetLabel: String {
        let trimmed = targetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Личное расписание" }
        return isGroup ? "Группа: \(trimmed)" : "Преподаватель: \(trimmed)"
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(reducedTransparency: reducedTransparency)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Target label badge
                        HStack(spacing: 8) {
                            Image(systemName: isGroup ? "person.3.fill" : "person.fill")
                                .foregroundColor(.uniPurple)
                            Text(targetLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(14)
                        .liquidGlassCard(cornerRadius: 16, reducedTransparency: reducedTransparency)

                        // Schedule Mode Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Когда повторять")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            HStack(spacing: 6) {
                                modeButton(title: "Конкретная дата", recurring: false)
                                modeButton(title: "Еженедельно", recurring: true)
                            }
                            .padding(4)
                            .liquidGlassCapsule(reducedTransparency: reducedTransparency)

                            if !isRecurring {
                                DatePicker(
                                    "Дата события",
                                    selection: $selectedDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("День недели")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.secondary)

                                    HStack(spacing: 6) {
                                        ForEach(1...6, id: \.self) { dow in
                                            let isSelected = (selectedDayOfWeek == dow)
                                            Button {
                                                HapticsService.shared.selection()
                                                selectedDayOfWeek = dow
                                            } label: {
                                                Text(Constants.dayNamesShort[dow - 1])
                                                    .font(.caption.bold())
                                                    .foregroundColor(isSelected ? .white : .primary)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                            .fill(isSelected ? Color.uniPurple : Color.primary.opacity(0.06))
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }

                                    Text("Неделя")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.secondary)

                                    HStack(spacing: 6) {
                                        ForEach(CustomEventWeekFilter.allCases) { filter in
                                            let isSelected = (selectedWeekFilter == filter)
                                            Button {
                                                HapticsService.shared.selection()
                                                selectedWeekFilter = filter
                                            } label: {
                                                Text(filter.displayName)
                                                    .font(.caption.bold())
                                                    .foregroundColor(isSelected ? .white : .primary)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        Capsule()
                                                            .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)

                        // Lesson slot picker 1...7
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Номер пары")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            HStack(spacing: 6) {
                                ForEach(1...7, id: \.self) { slot in
                                    let isSelected = (selectedLessonNumber == slot)
                                    Button {
                                        HapticsService.shared.selection()
                                        selectedLessonNumber = slot
                                    } label: {
                                        Text("\(slot)")
                                            .font(.subheadline.bold().monospacedDigit())
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            let effectiveDow = isRecurring
                                ? selectedDayOfWeek
                                : max(1, min(6, DateUtils.toScheduleDayOfWeek(date: selectedDate)))
                            let timeLabel = Constants.getLessonTimeLabel(dayOfWeek: effectiveDow, lessonNumber: selectedLessonNumber)
                            if !timeLabel.isEmpty {
                                Text("Время: \(timeLabel)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)

                        // Fields Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Детали события")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Название события / предмета *", text: $subjectName)
                                    .padding(12)
                                    .background(Color.primary.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(showTitleError ? Color.red : Color.clear, lineWidth: 1.2)
                                    )
                                    .onChange(of: subjectName) { _, newVal in
                                        if !newVal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            showTitleError = false
                                        }
                                    }

                                if showTitleError {
                                    Text("Введите название")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            TextField("Аудитория / место (необязательно)", text: $room)
                                .padding(12)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            TextField("Преподаватель / контакт (необязательно)", text: $teacherName)
                                .padding(12)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            TextField("Комментарий (необязательно)", text: $note, axis: .vertical)
                                .lineLimit(2...4)
                                .padding(12)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)
                    }
                    .padding()
                }
            }
            .navigationTitle("Личное событие")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveEvent()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func modeButton(title: String, recurring: Bool) -> some View {
        let isSelected = (isRecurring == recurring)
        return Button {
            HapticsService.shared.selection()
            withAnimation(.easeInOut(duration: 0.18)) {
                isRecurring = recurring
            }
        } label: {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func saveEvent() {
        let trimmedSubject = subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSubject.isEmpty else {
            showTitleError = true
            HapticsService.shared.notification(.error)
            return
        }

        let dateDow = DateUtils.toScheduleDayOfWeek(date: selectedDate)
        let resolvedDow = isRecurring ? selectedDayOfWeek : ((dateDow >= 1 && dateDow <= 6) ? dateDow : 1)
        let resolvedDateIso: String? = isRecurring ? nil : DateUtils.formatISODate(selectedDate)
        let resolvedWeekType = isRecurring ? selectedWeekFilter.rawValue : CustomEventWeekFilter.both.rawValue

        let event = CustomEvent(
            targetName: targetName.trimmingCharacters(in: .whitespacesAndNewlines),
            isGroup: isGroup,
            dateIso: resolvedDateIso,
            dayOfWeek: resolvedDow,
            weekType: resolvedWeekType,
            lessonNumber: selectedLessonNumber,
            subjectName: trimmedSubject,
            teacherName: teacherName.trimmingCharacters(in: .whitespacesAndNewlines),
            room: room.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        HapticsService.shared.notification(.success)
        onSaved(event)
        dismiss()
    }
}
