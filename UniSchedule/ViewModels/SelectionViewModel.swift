import Foundation
import SwiftUI
import Combine

public enum SelectionTab: String, CaseIterable, Identifiable {
    case groups = "Группы"
    case teachers = "Преподаватели"
    case favorites = "⭐ Избранное"
    
    public var id: String { rawValue }
}

@MainActor
public final class SelectionViewModel: ObservableObject {
    @Published public var searchText: String = ""
    @Published public var selectedTab: SelectionTab = .groups
    
    private let repository = ScheduleRepository.shared
    
    public init() {}
    
    public var filteredItems: [GroupOrTeacher] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        switch selectedTab {
        case .groups:
            let list = repository.groups.map { GroupOrTeacher(name: $0, type: .group, isFavorite: repository.isFavorite(name: $0, type: .group)) }
            if query.isEmpty { return list }
            return list.filter { $0.name.lowercased().contains(query) }
            
        case .teachers:
            let list = repository.teachers.map { GroupOrTeacher(name: $0, type: .teacher, isFavorite: repository.isFavorite(name: $0, type: .teacher)) }
            if query.isEmpty { return list }
            return list.filter { $0.name.lowercased().contains(query) }
            
        case .favorites:
            let list = repository.favorites
            if query.isEmpty { return list }
            return list.filter { $0.name.lowercased().contains(query) }
        }
    }
    
    public func toggleFavorite(item: GroupOrTeacher) {
        repository.toggleFavorite(name: item.name, type: item.type)
        HapticsService.shared.selection()
    }
}
