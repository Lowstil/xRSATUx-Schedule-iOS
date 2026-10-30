import SwiftUI

public struct FavoritesBarView: View {
    public let favorites: [GroupOrTeacher]
    public let currentTarget: String
    public let onSelect: (GroupOrTeacher) -> Void
    
    public init(
        favorites: [GroupOrTeacher],
        currentTarget: String,
        onSelect: @escaping (GroupOrTeacher) -> Void
    ) {
        self.favorites = favorites
        self.currentTarget = currentTarget
        self.onSelect = onSelect
    }
    
    public var body: some View {
        if !favorites.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(favorites) { item in
                        let isSelected = item.name.lowercased() == currentTarget.lowercased()
                        Button(action: {
                            onSelect(item)
                            HapticsService.shared.selection()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: item.type == .group ? "person.2.fill" : "person.crop.rectangle.fill")
                                    .font(.caption2)
                                Text(item.name)
                                    .font(.subheadline.bold())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                            .foregroundColor(isSelected ? .white : .primary)
                            .cornerRadius(18)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }
}

public struct SelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SelectionViewModel()
    
    public let onSelect: (String, Bool) -> Void
    
    public init(onSelect: @escaping (String, Bool) -> Void) {
        self.onSelect = onSelect
    }
    
    public var body: some View {
        NavigationStack {
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
                                viewModel.toggleFavorite(item: item)
                            }) {
                                Image(systemName: item.isFavorite ? "star.fill" : "star")
                                    .foregroundColor(item.isFavorite ? .yellow : .secondary)
                                    .padding(8)
                            }
                            .buttonStyle(.borderless)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(item.name, item.type == .group)
                            HapticsService.shared.selection()
                            dismiss()
                        }
                    }
                }
                .listStyle(.plain)
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
