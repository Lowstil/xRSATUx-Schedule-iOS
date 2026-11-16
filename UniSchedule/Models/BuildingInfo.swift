import Foundation

public struct BuildingMeta: Equatable {
    public let title: String
    public let address: String
    public let walkHint: String
    public let buildingFilter: String?
    public let hasPhysicalRooms: Bool

    public init(
        title: String,
        address: String,
        walkHint: String,
        buildingFilter: String?,
        hasPhysicalRooms: Bool
    ) {
        self.title = title
        self.address = address
        self.walkHint = walkHint
        self.buildingFilter = buildingFilter
        self.hasPhysicalRooms = hasPhysicalRooms
    }
}

public enum RoomFormatter {
    public static func parse(_ rawRoom: String) -> String {
        let trimmed = rawRoom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let lower = trimmed.lowercased()
        if lower.contains("точка кипения") {
            return "Точка кипения"
        }
        if lower.contains("спортзал") {
            return "Большой спортзал"
        }
        if lower.contains("онлайн") || lower.contains("online") || lower.contains("дистант") || lower.contains("saby") || lower.contains("сдо") {
            return "Онлайн"
        }
        if lower.contains("предприят") || lower.contains("практик") {
            return "Место практики"
        }

        if lower.hasPrefix("г-") || lower.hasPrefix("г ") || lower == "г" {
            return "Главный корпус · \(trimmed)"
        }
        if lower.hasPrefix("1-") || lower.hasPrefix("1 ") {
            return "Первый корпус · \(trimmed)"
        }
        if lower.hasPrefix("2-") || lower.hasPrefix("2 ") {
            return "Второй корпус · \(trimmed)"
        }
        if lower.hasPrefix("3-") || lower.hasPrefix("3 ") {
            return "Третий корпус · \(trimmed)"
        }

        return trimmed
    }

    public static func resolveBuildingMeta(from rawRoom: String) -> BuildingMeta {
        let trimmed = rawRoom.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        if lower.contains("точка кипения") {
            return BuildingMeta(
                title: "Точка кипения",
                address: "г. Рыбинск, ул. Пушкина, д. 53 (Главный корпус)",
                walkHint: "Внутри Главного корпуса · переход от 1-го корпуса ~2 мин",
                buildingFilter: nil,
                hasPhysicalRooms: false
            )
        }

        if lower.contains("спортзал") {
            return BuildingMeta(
                title: "Большой спортзал",
                address: "г. Рыбинск, ул. Пушкина, д. 53 (спортивный корпус)",
                walkHint: "Рядом с Главным корпусом ~2 мин пешком",
                buildingFilter: nil,
                hasPhysicalRooms: false
            )
        }

        if lower.contains("онлайн") || lower.contains("online") || lower.contains("дистант") || lower.contains("saby") || lower.contains("сдо") {
            return BuildingMeta(
                title: "Онлайн",
                address: "Дистанционный формат",
                walkHint: "Переход между корпусами не требуется",
                buildingFilter: nil,
                hasPhysicalRooms: false
            )
        }

        if lower.contains("предприят") || lower.contains("практик") {
            return BuildingMeta(
                title: "Место практики",
                address: "База производственной / учебной практики",
                walkHint: "Время в пути зависит от предприятия",
                buildingFilter: nil,
                hasPhysicalRooms: false
            )
        }

        if lower.hasPrefix("г-") || lower.hasPrefix("г ") || lower == "г" || lower.contains("главный") {
            return BuildingMeta(
                title: "Главный корпус",
                address: "г. Рыбинск, ул. Пушкина, д. 53",
                walkHint: "До 1-го корпуса ~2 мин · до 3-го ~3 мин · до 2-го ~7 мин пешком",
                buildingFilter: "Г",
                hasPhysicalRooms: true
            )
        }

        if lower.hasPrefix("1-") || lower.hasPrefix("1 ") || lower == "1" || lower.contains("первый") || lower.contains("1 корпус") {
            return BuildingMeta(
                title: "Первый корпус",
                address: "г. Рыбинск, ул. Плеханова, д. 2",
                walkHint: "До Главного корпуса ~2 мин · до 3-го ~2 мин · до 2-го ~8 мин пешком",
                buildingFilter: "1",
                hasPhysicalRooms: true
            )
        }

        if lower.hasPrefix("2-") || lower.hasPrefix("2 ") || lower == "2" || lower.contains("второй") || lower.contains("2 корпус") {
            return BuildingMeta(
                title: "Второй корпус",
                address: "г. Рыбинск, ул. Луначарского, д. 12",
                walkHint: "До Главного корпуса ~7 мин · до 1-го и 3-го ~8 мин пешком",
                buildingFilter: "2",
                hasPhysicalRooms: true
            )
        }

        if lower.hasPrefix("3-") || lower.hasPrefix("3 ") || lower == "3" || lower.contains("третий") || lower.contains("3 корпус") {
            return BuildingMeta(
                title: "Третий корпус",
                address: "г. Рыбинск, ул. Плеханова, д. 4",
                walkHint: "До Главного корпуса ~3 мин · до 1-го ~2 мин · до 2-го ~8 мин пешком",
                buildingFilter: "3",
                hasPhysicalRooms: true
            )
        }

        return BuildingMeta(
            title: trimmed.isEmpty ? "Аудитория" : trimmed,
            address: "г. Рыбинск, РГАТУ им. П. А. Соловьёва",
            walkHint: "Уточняйте расположение аудитории в расписании",
            buildingFilter: nil,
            hasPhysicalRooms: false
        )
    }
}
