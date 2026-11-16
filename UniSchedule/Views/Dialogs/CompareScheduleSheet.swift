import SwiftUI

@MainActor
public struct CompareScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency: Bool = false

    @ObservedObject public var viewModel: ScheduleViewModel
    private let initialSecondGroup: String?
    private let repository = ScheduleRepository.shared

    @State private var secondGroup: String?
    @State private var groupSearchQuery: String = ""
    @State private var isGroupPickerExpanded: Bool = false
    @State private var selectedWeek: Int
    @State private var selectedDayOfWeek: Int

    public init(viewModel: ScheduleViewModel, initialSecondGroup: String? = nil) {
        self.viewModel = viewModel
        self.initialSecondGroup = initialSecondGroup

        let initialWeek = min(max(1, viewModel.selectedWeekNumber), ScheduleViewModel.weekCount)
        _selectedWeek = State(initialValue: initialWeek)

        let dow = viewModel.selectedDayOfWeek
        _selectedDayOfWeek = State(initialValue: (dow >= 1 && dow <= 6) ? dow : 1)

        _secondGroup = State(initialValue: Self.resolveDefaultSecondGroup(
            primaryGroup: viewModel.selectedName,
            initialSecondGroup: initialSecondGroup,
            repository: ScheduleRepository.shared
        ))
    }

    private static func resolveDefaultSecondGroup(
        primaryGroup: String,
        initialSecondGroup: String?,
        repository: ScheduleRepository
    ) -> String? {
        let available = repository.groups.filter {
            $0.caseInsensitiveCompare(primaryGroup) != .orderedSame
        }
        if let initial = initialSecondGroup?.trimmingCharacters(in: .whitespacesAndNewlines),
           !initial.isEmpty,
           initial.caseInsensitiveCompare(primaryGroup) != .orderedSame {
            return available.first(where: { $0.caseInsensitiveCompare(initial) == .orderedSame }) ?? initial
        }
        let favGroups = repository.favorites
            .filter { $0.type == .group && $0.name.caseInsensitiveCompare(primaryGroup) != .orderedSame }
            .map(\.name)
        if let firstFav = favGroups.first {
            return firstFav
        }
        return available.first
    }

    private var availableGroups: [String] {
        repository.groups.filter {
            $0.caseInsensitiveCompare(viewModel.selectedName) != .orderedSame
        }
    }

    private var favoriteGroups: [String] {
        repository.favorites
            .filter { $0.type == .group && $0.name.caseInsensitiveCompare(viewModel.selectedName) != .orderedSame }
            .map(\.name)
    }

    private var filteredGroups: [String] {
        let q = groupSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return availableGroups }
        return availableGroups.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    private var isEvenSelectedWeek: Bool {
        viewModel.weekCalculator(for: viewModel.activeSemester).isEvenWeek(selectedWeek)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(reducedTransparency: reducedTransparency)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Header subtitle card
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(viewModel.selectedName) ↔ \(secondGroup ?? "Выберите группу")")
                                .font(.headline.bold())
                                .foregroundColor(.primary)

                            Text("Поиск общих окон и накладок по расписанию")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)

                        // Favorite groups quick chips
                        if !favoriteGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Избранные группы")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(favoriteGroups, id: \.self) { fav in
                                            let isSelected = (secondGroup?.caseInsensitiveCompare(fav) == .orderedSame)
                                            Button {
                                                HapticsService.shared.selection()
                                                secondGroup = fav
                                                isGroupPickerExpanded = false
                                            } label: {
                                                Text(fav)
                                                    .font(.caption.bold())
                                                    .foregroundColor(isSelected ? .white : .primary)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 7)
                                                    .liquidGlassCapsule(
                                                        tint: isSelected ? .accentColor : nil,
                                                        reducedTransparency: reducedTransparency
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        // Searchable second-group selector
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                HapticsService.shared.selection()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isGroupPickerExpanded.toggle()
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Вторая группа")
                                            .font(.caption.bold())
                                            .foregroundColor(.secondary)
                                        Text(secondGroup ?? "Выберите группу")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.primary)
                                    }
                                    Spacer()
                                    Image(systemName: isGroupPickerExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            if isGroupPickerExpanded {
                                SearchBarView(text: $groupSearchQuery, placeholder: "Поиск группы...")

                                if filteredGroups.isEmpty {
                                    Text("Группы не найдены")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 6)
                                } else {
                                    ScrollView {
                                        LazyVStack(spacing: 6) {
                                            ForEach(filteredGroups, id: \.self) { group in
                                                let isSelected = (secondGroup?.caseInsensitiveCompare(group) == .orderedSame)
                                                Button {
                                                    HapticsService.shared.selection()
                                                    secondGroup = group
                                                    isGroupPickerExpanded = false
                                                } label: {
                                                    HStack {
                                                        Text(group)
                                                            .font(.subheadline.weight(isSelected ? .bold : .regular))
                                                            .foregroundColor(.primary)
                                                        Spacer()
                                                        if isSelected {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .foregroundColor(.accentColor)
                                                        }
                                                    }
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                            .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 200)
                                }
                            }
                        }
                        .padding(14)
                        .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)

                        // Week stepper + Day buttons
                        VStack(spacing: 12) {
                            HStack {
                                Button {
                                    guard selectedWeek > 1 else { return }
                                    selectedWeek -= 1
                                    HapticsService.shared.selection()
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                        .frame(width: 34, height: 34)
                                        .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                                }
                                .buttonStyle(.plain)
                                .disabled(selectedWeek <= 1)
                                .opacity(selectedWeek <= 1 ? 0.35 : 1.0)

                                Spacer()

                                Text("Неделя \(selectedWeek) (\(isEvenSelectedWeek ? "чётная" : "нечётная"))")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)

                                Spacer()

                                Button {
                                    guard selectedWeek < ScheduleViewModel.weekCount else { return }
                                    selectedWeek += 1
                                    HapticsService.shared.selection()
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                        .frame(width: 34, height: 34)
                                        .liquidGlassCapsule(reducedTransparency: reducedTransparency)
                                }
                                .buttonStyle(.plain)
                                .disabled(selectedWeek >= ScheduleViewModel.weekCount)
                                .opacity(selectedWeek >= ScheduleViewModel.weekCount ? 0.35 : 1.0)
                            }

                            HStack(spacing: 6) {
                                ForEach(1...6, id: \.self) { dow in
                                    let isSelected = (selectedDayOfWeek == dow)
                                    Button {
                                        selectedDayOfWeek = dow
                                        HapticsService.shared.selection()
                                    } label: {
                                        Text(Constants.dayNamesShort[dow - 1])
                                            .font(.caption.bold())
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
                        }
                        .padding(14)
                        .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)

                        // Comparison results
                        if let other = secondGroup, !other.isEmpty {
                            let result = viewModel.buildDayComparison(
                                group1: viewModel.selectedName,
                                group2: other,
                                semester: viewModel.activeSemester,
                                weekNumber: selectedWeek,
                                dayOfWeek: selectedDayOfWeek
                            )

                            Text(result.summaryText)
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .liquidGlassCapsule(reducedTransparency: reducedTransparency)

                            ForEach(result.slots) { slot in
                                comparisonSlotCard(slot, group1: result.group1, group2: result.group2)
                            }
                        } else {
                            Text("Выберите вторую группу для сравнения расписания")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(20)
                                .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Сравнение групп")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .onAppear {
                if secondGroup == nil {
                    secondGroup = Self.resolveDefaultSecondGroup(
                        primaryGroup: viewModel.selectedName,
                        initialSecondGroup: initialSecondGroup,
                        repository: repository
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func comparisonSlotCard(_ slot: CompareSlotEntry, group1: String, group2: String) -> some View {
        switch slot.kind {
        case .commonWindow:
            VStack(alignment: .leading, spacing: 6) {
                Text("🟢 Общее окно · \(slot.lessonNumber) пара (\(slot.timeLabel))")
                    .font(.subheadline.bold())
                    .foregroundColor(.uniLiveEmerald)

                Text("Обе группы свободны")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .liquidGlassCard(cornerRadius: 18, state: .live, reducedTransparency: reducedTransparency)

        case .bothBusy:
            VStack(alignment: .leading, spacing: 6) {
                Text("🔵 Заняты оба · \(slot.lessonNumber) пара (\(slot.timeLabel))")
                    .font(.subheadline.bold())
                    .foregroundColor(.uniNextSky)

                Text("\(group1): \(slot.group1Text ?? "")")
                    .font(.caption)
                    .foregroundColor(.primary)

                Text("\(group2): \(slot.group2Text ?? "")")
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .liquidGlassCard(cornerRadius: 18, state: .next, reducedTransparency: reducedTransparency)

        case .oneBusy:
            VStack(alignment: .leading, spacing: 6) {
                Text("🟡 Занята одна группа · \(slot.lessonNumber) пара (\(slot.timeLabel))")
                    .font(.subheadline.bold())
                    .foregroundColor(.uniWindowAmber)

                Text("\(group1): \(slot.group1Text ?? "свободно")")
                    .font(.caption)
                    .foregroundColor(slot.group1Text == nil ? .secondary : .primary)

                Text("\(group2): \(slot.group2Text ?? "свободно")")
                    .font(.caption)
                    .foregroundColor(slot.group2Text == nil ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.uniWindowAmber.opacity(0.08))
            )
            .liquidGlassCard(cornerRadius: 18, state: .normal, reducedTransparency: reducedTransparency)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.uniWindowAmber.opacity(0.42), lineWidth: 1.2)
            )
        }
    }
}
