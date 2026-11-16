import SwiftUI

public struct FavoritesBarView: View {
    public let favorites: [GroupOrTeacher]
    public let currentTarget: String
    public let onSelect: (GroupOrTeacher) -> Void
    public let onRemove: ((GroupOrTeacher) -> Void)?
    public let onCompare: ((SelectionType, String) -> Void)?
    
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false
    @State private var favoriteActionTarget: GroupOrTeacher? = nil
    
    public init(
        favorites: [GroupOrTeacher],
        currentTarget: String,
        onSelect: @escaping (GroupOrTeacher) -> Void,
        onRemove: ((GroupOrTeacher) -> Void)? = nil,
        onCompare: ((SelectionType, String) -> Void)? = nil
    ) {
        self.favorites = favorites
        self.currentTarget = currentTarget
        self.onSelect = onSelect
        self.onRemove = onRemove
        self.onCompare = onCompare
    }
    
    public var body: some View {
        if !favorites.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(favorites) { item in
                        let isSelected = item.name.lowercased() == currentTarget.lowercased()
                        
                        HStack(spacing: 6) {
                            Image(systemName: item.type == .group ? "person.2.fill" : "person.crop.rectangle.fill")
                                .font(.caption2)
                            Text(item.name)
                                .font(.subheadline.bold())
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .foregroundColor(isSelected ? .white : .primary)
                        .background(
                            Group {
                                if isSelected {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.accentColor, Color.uniNextSky.opacity(0.9)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                } else {
                                    Capsule().fill(Color.clear)
                                }
                            }
                        )
                        .liquidGlassCapsule(
                            tint: isSelected ? .accentColor : nil,
                            reducedTransparency: reducedTransparency
                        )
                        .contentShape(Capsule())
                        .onTapGesture {
                            onSelect(item)
                            HapticsService.shared.selection()
                        }
                        .onLongPressGesture(minimumDuration: 0.45) {
                            HapticsService.shared.impact(.medium)
                            favoriteActionTarget = item
                        }
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            .confirmationDialog(
                favoriteActionTarget?.name ?? "Избранное",
                isPresented: Binding(
                    get: { favoriteActionTarget != nil },
                    set: { if !$0 { favoriteActionTarget = nil } }
                ),
                titleVisibility: .visible,
                presenting: favoriteActionTarget
            ) { item in
                if item.type == .group,
                   item.name.caseInsensitiveCompare(currentTarget) != .orderedSame,
                   let onCompare {
                    Button("⚖️ Сравнить с текущей") {
                        HapticsService.shared.selection()
                        onCompare(item.type, item.name)
                        favoriteActionTarget = nil
                    }
                }

                Button("🗑 Удалить из избранного", role: .destructive) {
                    HapticsService.shared.notification(.warning)
                    removeFavorite(item)
                }

                Button("Отмена", role: .cancel) {
                    favoriteActionTarget = nil
                }
            }
        }
    }
    
    private func removeFavorite(_ item: GroupOrTeacher) {
        if let onRemove {
            onRemove(item)
        } else if ScheduleRepository.shared.isFavorite(name: item.name, type: item.type) {
            ScheduleRepository.shared.toggleFavorite(name: item.name, type: item.type)
        }
        favoriteActionTarget = nil
    }
}

public struct SelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SelectionViewModel()
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false
    
    public let onSelect: (String, Bool) -> Void
    
    public init(onSelect: @escaping (String, Bool) -> Void) {
        self.onSelect = onSelect
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(reducedTransparency: reducedTransparency)
                
                VStack(spacing: 12) {
                    SearchBarView(text: $viewModel.searchText)
                        .padding(.horizontal)
                    
                    Picker("Раздел", selection: $viewModel.selectedTab) {
                        ForEach(SelectionTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    List {
                        ForEach(viewModel.filteredItems) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.body.weight(.medium))
                                    Text(item.type.title)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    HapticsService.shared.selection()
                                    viewModel.toggleFavorite(item: item)
                                }) {
                                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                                        .foregroundColor(item.isFavorite ? .uniWindowAmber : .secondary)
                                        .padding(8)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .liquidGlassCard(cornerRadius: 14, state: .normal, reducedTransparency: reducedTransparency)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(item.name, item.type == .group)
                                HapticsService.shared.selection()
                                dismiss()
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Выбор расписания")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}
