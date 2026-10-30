import Foundation

public struct ParsedScheduleData: Codable {
    public var version: String
    public var lastUpdated: String
    public var semesterStart: String
    public var groups: [String]
    public var teachers: [String]
    public var items: [ScheduleItem]
}

public final class ScheduleParser {
    public static let shared = ScheduleParser()
    
    private init() {}
    
    public func parseScheduleJSON(data: Data) throws -> ParsedScheduleData {
        let decoder = JSONDecoder()
        return try decoder.decode(ParsedScheduleData.self, from: data)
    }
    
    public func loadBundledSampleSchedule() -> ParsedScheduleData? {
        guard let url = Bundle.main.url(forResource: "SampleSchedule", withExtension: "json") else {
            // Check direct path if in development / test environment
            let fallbackURL = URL(fileURLWithPath: "UniSchedule/Resources/SampleSchedule.json")
            if let data = try? Data(contentsOf: fallbackURL) {
                return try? parseScheduleJSON(data: data)
            }
            return nil
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? parseScheduleJSON(data: data)
    }
}
