import Foundation
import Combine

public final class ScheduleRepository: ObservableObject {
    public static let shared = ScheduleRepository()

    private struct FastTargetCache: Codable {
        let targetName: String
        let isGroup: Bool
        let items: [ScheduleItem]
        let groups: [String]
        let teachers: [String]
        let lastUpdated: Date?
    }

    private struct SemesterIndexBundle {
        let items: [ScheduleItem]
        let groups: [String]
        let teachers: [String]
        let lastUpdated: Date
        let groupIndex: [String: [ScheduleItem]]
        let teacherIndex: [String: [ScheduleItem]]
        let distinctRooms: [String]
        let occupiedRooms: [String: Set<String>]
        let teacherDisplayNames: [String]
    }

    @Published public private(set) var activeSemester: SemesterType
    @Published public private(set) var allItems: [ScheduleItem] = []
    @Published public private(set) var groups: [String] = []
    @Published public private(set) var teachers: [String] = []
    @Published public private(set) var favorites: [GroupOrTeacher] = []
    @Published public private(set) var notes: [LessonNote] = []
    @Published public private(set) var pendingNotesCount: Int = 0
    @Published public private(set) var customEvents: [CustomEvent] = []
    @Published public private(set) var lastUpdated: Date? = nil
    @Published public private(set) var isUpdating: Bool = false
    @Published public private(set) var updateErrorMessage: String? = nil
    @Published public private(set) var lastScheduleDiff: ScheduleDiffResult? = nil

    private let userDefaults: UserDefaults
    private var semesterItems: [SemesterType: [ScheduleItem]] = [:]
    private var semesterGroups: [SemesterType: [String]] = [:]
    private var semesterTeachers: [SemesterType: [String]] = [:]
    private var semesterLastUpdated: [SemesterType: Date] = [:]
    private var semesterGroupIndex: [SemesterType: [String: [ScheduleItem]]] = [:]
    private var semesterTeacherIndex: [SemesterType: [String: [ScheduleItem]]] = [:]
    private var semesterDistinctRooms: [SemesterType: [String]] = [:]
    private var semesterOccupiedRooms: [SemesterType: [String: Set<String>]] = [:]
    private var semesterTeacherDisplayNames: [SemesterType: [String]] = [:]
    private var hydrationEpoch: Int = 0

    private var documentsDir: URL {
        Self.resolveDocumentsDir()
    }

    private static func resolveDocumentsDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var legacyCacheFileURL: URL {
        documentsDir.appendingPathComponent("schedule_data.json")
    }

    private var legacyCachedXLSXURL: URL {
        documentsDir.appendingPathComponent(Constants.scheduleCacheFileName)
    }

    private func cacheFileURL(for semester: SemesterType) -> URL {
        Self.cacheFileURL(for: semester, documentsDir: documentsDir)
    }

    private static func cacheFileURL(for semester: SemesterType, documentsDir: URL) -> URL {
        documentsDir.appendingPathComponent("schedule_data_\(semester.rawValue).json")
    }

    private func cachedXLSXURL(for semester: SemesterType) -> URL {
        Self.cachedXLSXURL(for: semester, documentsDir: documentsDir)
    }

    private static func cachedXLSXURL(for semester: SemesterType, documentsDir: URL) -> URL {
        documentsDir.appendingPathComponent("schedule_cache_\(semester.rawValue).xlsx")
    }

    private func fastTargetCacheURL(for semester: SemesterType) -> URL {
        Self.fastTargetCacheURL(for: semester, documentsDir: documentsDir)
    }

    private static func fastTargetCacheURL(for semester: SemesterType, documentsDir: URL) -> URL {
        documentsDir.appendingPathComponent("fast_target_\(semester.rawValue).json")
    }

    private var notePhotosDir: URL {
        documentsDir.appendingPathComponent("note_photos", isDirectory: true)
    }

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.activeSemester = SemesterManager.loadActiveSemester(userDefaults: userDefaults)
        loadFastTargetSnapshotOnInit()
        loadFavorites()
        loadNotes()
        loadCustomEvents()
        loadScheduleDiff()

        let epoch = hydrationEpoch
        Task {
            await hydrateFullDataInBackground(expectedEpoch: epoch)
            await maybeAutoRefresh()
        }
    }

    // MARK: - Instant Boot Fast-Target Snapshot & Background Hydration
    private func loadFastTargetSnapshotOnInit() {
        let sem = activeSemester
        let url = fastTargetCacheURL(for: sem)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(FastTargetCache.self, from: data) else {
            return
        }

        let formatter = ISO8601DateFormatter()
        let parsed = ParsedScheduleData(
            version: "fast",
            lastUpdated: snapshot.lastUpdated.map { formatter.string(from: $0) } ?? "",
            semesterStart: "",
            groups: snapshot.groups,
            teachers: snapshot.teachers,
            items: snapshot.items
        )
        let fallbackDate = snapshot.lastUpdated ?? (userDefaults.object(forKey: Constants.prefLastUpdated) as? Date)
        let bundle = Self.buildIndexBundle(from: parsed, fallbackLastUpdated: fallbackDate)
        applyBundle(bundle, for: sem)
        if let lu = snapshot.lastUpdated {
            semesterLastUpdated[sem] = lu
        }
        if userDefaults.object(forKey: Constants.prefSemesterPublishedPrefix + sem.rawValue) == nil,
           !snapshot.items.isEmpty {
            setSemesterPublished(true, for: sem)
        }
        syncPublishedStateForActiveSemester()
    }

    public func saveFastTargetCache(for semester: SemesterType, targetName: String? = nil, isGroup: Bool? = nil) {
        let resolvedName = (targetName ?? userDefaults.string(forKey: Constants.prefSelectionName) ?? "ИВБ-24")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedIsGroup = isGroup ?? ((userDefaults.string(forKey: Constants.prefSelectionType) ?? "group") == "group")
        guard !resolvedName.isEmpty, !(semesterItems[semester] ?? []).isEmpty else { return }

        let targetItems = rawIndexedItems(for: resolvedName.lowercased(), isGroup: resolvedIsGroup, semester: semester)
        let allSemGroups = semesterGroups[semester] ?? groups
        let allSemTeachers = semesterTeachers[semester] ?? teachers
        let lu = semesterLastUpdated[semester] ?? lastUpdated
        let url = fastTargetCacheURL(for: semester)

        Self.writeFastTargetCache(
            to: url,
            targetName: resolvedName,
            isGroup: resolvedIsGroup,
            items: targetItems,
            groups: allSemGroups,
            teachers: allSemTeachers,
            lastUpdated: lu
        )
    }

    private static func writeFastTargetCache(
        to url: URL,
        targetName: String,
        isGroup: Bool,
        items: [ScheduleItem],
        groups: [String],
        teachers: [String],
        lastUpdated: Date?
    ) {
        let payload = FastTargetCache(
            targetName: targetName,
            isGroup: isGroup,
            items: items,
            groups: groups,
            teachers: teachers,
            lastUpdated: lastUpdated
        )
        if let encoded = try? JSONEncoder().encode(payload) {
            try? encoded.write(to: url, options: .atomic)
        }
    }

    private func hydrateFullDataInBackground(expectedEpoch: Int) async {
        let docsDir = documentsDir
        let savedName = (userDefaults.string(forKey: Constants.prefSelectionName) ?? "ИВБ-24")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let savedIsGroup = (userDefaults.string(forKey: Constants.prefSelectionType) ?? "group") == "group"
        let fallbackLastUpdated = userDefaults.object(forKey: Constants.prefLastUpdated) as? Date
        var missingPublishedFlags: [SemesterType: Bool] = [:]
        for sem in SemesterType.allCases {
            missingPublishedFlags[sem] = (userDefaults.object(forKey: Constants.prefSemesterPublishedPrefix + sem.rawValue) == nil)
        }

        let loaded = await Task.detached(priority: .userInitiated) { () -> (bundles: [SemesterType: SemesterIndexBundle], newlyPublished: Set<SemesterType>) in
            Self.migrateLegacyCacheFiles(documentsDir: docsDir)
            var result: [SemesterType: SemesterIndexBundle] = [:]
            var toPublish = Set<SemesterType>()

            for semester in SemesterType.allCases {
                if let parsed = Self.loadSemesterCacheFromDisk(for: semester, documentsDir: docsDir), !parsed.items.isEmpty {
                    result[semester] = Self.buildIndexBundle(from: parsed, fallbackLastUpdated: fallbackLastUpdated)
                    if missingPublishedFlags[semester] == true {
                        toPublish.insert(semester)
                    }
                }
            }

            if result[.fall] == nil {
                if let sample = ScheduleParser.shared.loadBundledSampleSchedule(), !sample.items.isEmpty {
                    result[.fall] = Self.buildIndexBundle(from: sample, fallbackLastUpdated: fallbackLastUpdated)
                    toPublish.insert(.fall)
                } else if let bundleXlsx = Bundle.main.url(forResource: "schedule", withExtension: "xlsx"),
                          let parsed = try? XLSXReader.shared.parseSchedule(xlsxURL: bundleXlsx),
                          !parsed.items.isEmpty {
                    result[.fall] = Self.buildIndexBundle(from: parsed, fallbackLastUpdated: fallbackLastUpdated)
                    Self.writeParsedDataToCache(parsed, for: .fall, documentsDir: docsDir)
                    toPublish.insert(.fall)
                }
            }

            // Refresh fast_target_<sem>.json off the main thread using indexed items
            for (sem, bundle) in result where !savedName.isEmpty {
                let clean = savedName.lowercased()
                let targetItems: [ScheduleItem]
                if savedIsGroup {
                    targetItems = bundle.groupIndex[clean] ?? []
                } else if let indexed = bundle.teacherIndex[clean], !indexed.isEmpty {
                    targetItems = indexed
                } else {
                    targetItems = bundle.items.filter { $0.teacherName.lowercased().contains(clean) }
                }
                Self.writeFastTargetCache(
                    to: Self.fastTargetCacheURL(for: sem, documentsDir: docsDir),
                    targetName: savedName,
                    isGroup: savedIsGroup,
                    items: targetItems,
                    groups: bundle.groups,
                    teachers: bundle.teachers,
                    lastUpdated: bundle.lastUpdated
                )
            }

            return (result, toPublish)
        }.value

        await MainActor.run {
            guard expectedEpoch == self.hydrationEpoch else { return }

            var didChange = false
            for (sem, bundle) in loaded.bundles {
                let existing = self.semesterItems[sem] ?? []
                let itemsChanged = existing.count != bundle.items.count || existing != bundle.items
                let listsChanged = (self.semesterGroups[sem] ?? []) != bundle.groups || (self.semesterTeachers[sem] ?? []) != bundle.teachers
                if itemsChanged || listsChanged || self.semesterGroupIndex[sem] == nil {
                    self.applyBundle(bundle, for: sem)
                    didChange = true
                }
                if loaded.newlyPublished.contains(sem) {
                    self.setSemesterPublished(true, for: sem)
                }
            }

            if didChange {
                self.syncPublishedStateForActiveSemester()
            }
        }
    }

    // MARK: - Initial Load & Per-Semester Migration
    public func loadFromCacheOrBundle() {
        hydrationEpoch += 1
        migrateLegacyCacheIfNeeded()

        semesterItems.removeAll()
        semesterGroups.removeAll()
        semesterTeachers.removeAll()
        semesterLastUpdated.removeAll()
        semesterGroupIndex.removeAll()
        semesterTeacherIndex.removeAll()
        semesterDistinctRooms.removeAll()
        semesterOccupiedRooms.removeAll()
        semesterTeacherDisplayNames.removeAll()

        for semester in SemesterType.allCases {
            if let parsed = loadSemesterCache(for: semester), !parsed.items.isEmpty {
                storeParsedData(parsed, for: semester)
                if userDefaults.object(forKey: Constants.prefSemesterPublishedPrefix + semester.rawValue) == nil {
                    setSemesterPublished(true, for: semester)
                }
            }
        }

        // Fresh install fallback: load bundled sample/xlsx into .fall only
        if (semesterItems[.fall] ?? []).isEmpty {
            if let sample = ScheduleParser.shared.loadBundledSampleSchedule(), !sample.items.isEmpty {
                storeParsedData(sample, for: .fall)
                setSemesterPublished(true, for: .fall)
            } else if let bundleXlsx = Bundle.main.url(forResource: "schedule", withExtension: "xlsx"),
                      let parsed = try? XLSXReader.shared.parseSchedule(xlsxURL: bundleXlsx),
                      !parsed.items.isEmpty {
                storeParsedData(parsed, for: .fall)
                saveParsedDataToCache(parsed, for: .fall)
                setSemesterPublished(true, for: .fall)
            }
        }

        syncPublishedStateForActiveSemester()
        for semester in SemesterType.allCases where !(semesterItems[semester] ?? []).isEmpty {
            saveFastTargetCache(for: semester)
        }
    }

    private func migrateLegacyCacheIfNeeded() {
        let migrated = Self.migrateLegacyCacheFiles(documentsDir: documentsDir)
        if migrated && userDefaults.object(forKey: Constants.prefSemesterPublishedPrefix + SemesterType.fall.rawValue) == nil {
            setSemesterPublished(true, for: .fall)
        }
    }

    @discardableResult
    private static func migrateLegacyCacheFiles(documentsDir: URL) -> Bool {
        let fm = FileManager.default
        let legacyJson = documentsDir.appendingPathComponent("schedule_data.json")
        let fallJson = cacheFileURL(for: .fall, documentsDir: documentsDir)
        var didMoveJson = false
        if fm.fileExists(atPath: legacyJson.path) && !fm.fileExists(atPath: fallJson.path) {
            try? fm.moveItem(at: legacyJson, to: fallJson)
            didMoveJson = true
        }
        let legacyXlsx = documentsDir.appendingPathComponent(Constants.scheduleCacheFileName)
        let fallXlsx = cachedXLSXURL(for: .fall, documentsDir: documentsDir)
        if fm.fileExists(atPath: legacyXlsx.path) && !fm.fileExists(atPath: fallXlsx.path) {
            try? fm.moveItem(at: legacyXlsx, to: fallXlsx)
        }
        return didMoveJson
    }

    private func loadSemesterCache(for semester: SemesterType) -> ParsedScheduleData? {
        Self.loadSemesterCacheFromDisk(for: semester, documentsDir: documentsDir)
    }

    private static func loadSemesterCacheFromDisk(for semester: SemesterType, documentsDir: URL) -> ParsedScheduleData? {
        let fm = FileManager.default
        let jsonURL = cacheFileURL(for: semester, documentsDir: documentsDir)
        if fm.fileExists(atPath: jsonURL.path),
           let data = try? Data(contentsOf: jsonURL),
           let parsed = try? ScheduleParser.shared.parseScheduleJSON(data: data),
           !parsed.items.isEmpty {
            return parsed
        }

        let xlsxURL = cachedXLSXURL(for: semester, documentsDir: documentsDir)
        if fm.fileExists(atPath: xlsxURL.path),
           let parsed = try? XLSXReader.shared.parseSchedule(xlsxURL: xlsxURL),
           !parsed.items.isEmpty {
            writeParsedDataToCache(parsed, for: semester, documentsDir: documentsDir)
            return parsed
        }

        return nil
    }

    private func storeParsedData(_ data: ParsedScheduleData, for semester: SemesterType) {
        let fallbackDate = userDefaults.object(forKey: Constants.prefLastUpdated) as? Date
        let bundle = Self.buildIndexBundle(from: data, fallbackLastUpdated: fallbackDate)
        applyBundle(bundle, for: semester)
    }

    private func applyBundle(_ bundle: SemesterIndexBundle, for semester: SemesterType) {
        semesterItems[semester] = bundle.items
        semesterGroups[semester] = bundle.groups
        semesterTeachers[semester] = bundle.teachers
        semesterLastUpdated[semester] = bundle.lastUpdated
        semesterGroupIndex[semester] = bundle.groupIndex
        semesterTeacherIndex[semester] = bundle.teacherIndex
        semesterDistinctRooms[semester] = bundle.distinctRooms
        semesterOccupiedRooms[semester] = bundle.occupiedRooms
        semesterTeacherDisplayNames[semester] = bundle.teacherDisplayNames
    }

    private static func buildIndexBundle(
        from data: ParsedScheduleData,
        fallbackLastUpdated: Date?
    ) -> SemesterIndexBundle {
        var groupIndex: [String: [ScheduleItem]] = [:]
        var teacherIndex: [String: [ScheduleItem]] = [:]
        var roomSeen: [String: String] = [:]
        var occupiedRooms: [String: Set<String>] = [:]
        var teacherNameSeen: [String: String] = [:]
        let separators = CharacterSet(charactersIn: ",;/")

        for t in data.teachers {
            for part in t.components(separatedBy: separators) {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != "-", trimmed != "—" else { continue }
                let key = trimmed.lowercased()
                if teacherNameSeen[key] == nil {
                    teacherNameSeen[key] = trimmed
                }
            }
        }

        for item in data.items {
            let gKey = item.groupName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !gKey.isEmpty {
                groupIndex[gKey, default: []].append(item)
            }

            let rawTeacher = item.teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !rawTeacher.isEmpty, rawTeacher != "-", rawTeacher != "—" {
                var addedKeys = Set<String>()
                for part in rawTeacher.components(separatedBy: separators) {
                    let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, trimmed != "-", trimmed != "—" else { continue }
                    let tKey = trimmed.lowercased()
                    if teacherNameSeen[tKey] == nil {
                        teacherNameSeen[tKey] = trimmed
                    }
                    if addedKeys.insert(tKey).inserted {
                        teacherIndex[tKey, default: []].append(item)
                    }
                }
                let fullKey = rawTeacher.lowercased()
                if addedKeys.insert(fullKey).inserted {
                    teacherIndex[fullKey, default: []].append(item)
                }
            }

            let room = item.room.trimmingCharacters(in: .whitespacesAndNewlines)
            if isPhysicalRoomStatic(room) {
                let rKey = room.lowercased()
                if roomSeen[rKey] == nil {
                    roomSeen[rKey] = room
                }
            }

            if !item.isCancelled, !room.isEmpty {
                let slotKey = "\(item.weekType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())_\(item.dayOfWeek)_\(item.lessonNumber)"
                occupiedRooms[slotKey, default: []].insert(room.lowercased())
            }
        }

        let distinctRooms = roomSeen.values.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let teacherDisplayNames = teacherNameSeen.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        let isoFormatter = ISO8601DateFormatter()
        let resolvedLastUpdated = isoFormatter.date(from: data.lastUpdated)
            ?? fallbackLastUpdated
            ?? Date()

        return SemesterIndexBundle(
            items: data.items,
            groups: data.groups,
            teachers: data.teachers,
            lastUpdated: resolvedLastUpdated,
            groupIndex: groupIndex,
            teacherIndex: teacherIndex,
            distinctRooms: distinctRooms,
            occupiedRooms: occupiedRooms,
            teacherDisplayNames: teacherDisplayNames
        )
    }

    private func syncPublishedStateForActiveSemester() {
        let nextItems = semesterItems[activeSemester] ?? []
        if self.allItems.count != nextItems.count || self.allItems != nextItems {
            self.allItems = nextItems
        }

        let nextLastUpdated = semesterLastUpdated[activeSemester] ?? (userDefaults.object(forKey: Constants.prefLastUpdated) as? Date)
        if self.lastUpdated != nextLastUpdated {
            self.lastUpdated = nextLastUpdated
        }

        var groupSet = Set<String>()
        var teacherSet = Set<String>()
        for semester in SemesterType.allCases {
            for g in semesterGroups[semester] ?? [] { groupSet.insert(g) }
            for t in semesterTeachers[semester] ?? [] { teacherSet.insert(t) }
        }
        if groupSet.isEmpty {
            for item in semesterItems.values.flatMap({ $0 }) {
                let g = item.groupName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !g.isEmpty { groupSet.insert(g) }
                let t = item.teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { teacherSet.insert(t) }
            }
        }
        let sortedGroups = groupSet.sorted()
        let sortedTeachers = teacherSet.sorted()
        if self.groups != sortedGroups {
            self.groups = sortedGroups
        }
        if self.teachers != sortedTeachers {
            self.teachers = sortedTeachers
        }
    }

    private func saveParsedDataToCache(_ data: ParsedScheduleData, for semester: SemesterType) {
        if Self.writeParsedDataToCache(data, for: semester, documentsDir: documentsDir) {
            userDefaults.set(Date(), forKey: Constants.prefLastUpdated)
        }
    }

    @discardableResult
    private static func writeParsedDataToCache(_ data: ParsedScheduleData, for semester: SemesterType, documentsDir: URL) -> Bool {
        guard let encoded = try? JSONEncoder().encode(data) else { return false }
        do {
            try encoded.write(to: cacheFileURL(for: semester, documentsDir: documentsDir), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Dual Semester State & SHA-256 Resolution
    public func isSemesterPublished(_ semester: SemesterType) -> Bool {
        let flag = userDefaults.bool(forKey: Constants.prefSemesterPublishedPrefix + semester.rawValue)
        return flag && !(semesterItems[semester] ?? []).isEmpty
    }

    public func setSemesterPublished(_ published: Bool, for semester: SemesterType) {
        userDefaults.set(published, forKey: Constants.prefSemesterPublishedPrefix + semester.rawValue)
    }

    public func getSemesterHash(_ semester: SemesterType) -> String? {
        userDefaults.string(forKey: Constants.prefSemesterHashPrefix + semester.rawValue)
    }

    public func setSemesterHash(_ hash: String?, for semester: SemesterType) {
        let key = Constants.prefSemesterHashPrefix + semester.rawValue
        if let hash, !hash.isEmpty {
            userDefaults.set(hash, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    public func setActiveSemester(_ semester: SemesterType) {
        SemesterManager.saveActiveSemester(semester, userDefaults: userDefaults)
        if Thread.isMainThread {
            self.activeSemester = semester
            self.syncPublishedStateForActiveSemester()
        } else {
            DispatchQueue.main.async {
                self.activeSemester = semester
                self.syncPublishedStateForActiveSemester()
            }
        }
    }

    public func items(for semester: SemesterType) -> [ScheduleItem] {
        semesterItems[semester] ?? []
    }

    public func resolveTargetSemesterForDownload(
        windowSemester: SemesterType,
        today: Date = Date(),
        newHash: String?
    ) -> SemesterType {
        if isSemesterPublished(windowSemester) {
            return windowSemester
        }

        let other = windowSemester.other
        if let otherHash = getSemesterHash(other), !otherHash.isEmpty {
            if let newHash, !newHash.isEmpty, newHash != otherHash {
                return windowSemester
            } else {
                return other
            }
        }

        let month = Calendar.current.component(.month, from: today)
        switch windowSemester {
        case .spring:
            return (month >= 2) ? .spring : .fall
        case .fall:
            return (month >= 9 || month == 1) ? .fall : .spring
        }
    }

    // MARK: - Auto-Refresh Logic
    public func shouldAutoRefresh() -> Bool {
        if allItems.isEmpty { return true }
        guard let lu = lastUpdated else { return true }
        let hours = Calendar.current.dateComponents([.hour], from: lu, to: Date()).hour ?? 0
        return hours >= 24
    }

    public func maybeAutoRefresh() async {
        guard shouldAutoRefresh() else { return }
        do {
            try await refreshSchedule()
        } catch {
            print("Auto-refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Remote Refresh (Downloads & Parses .xlsx from rsatu.ru)
    public func refreshSchedule() async throws {
        await MainActor.run {
            self.isUpdating = true
            self.updateErrorMessage = nil
        }
        defer {
            Task { @MainActor in self.isUpdating = false }
        }

        // 1. Download schedule.xlsx to temp URL & compute SHA-256 hash
        let tempXLSXURL = documentsDir.appendingPathComponent("schedule_download_tmp.xlsx")
        try await NetworkService.shared.fetchScheduleFile(cacheURL: tempXLSXURL)
        let newHash = NetworkService.shared.lastDownloadedHash

        // 2. Parse downloaded schedule.xlsx
        let parsed = try XLSXReader.shared.parseSchedule(xlsxURL: tempXLSXURL)
        guard !parsed.items.isEmpty else {
            try? FileManager.default.removeItem(at: tempXLSXURL)
            throw NSError(domain: "ScheduleRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Файл расписания пуст или не содержит занятий"])
        }

        let now = Date()
        let windowSem = SemesterManager.getCurrentWindowSemester(today: now)
        let targetSem = resolveTargetSemesterForDownload(windowSemester: windowSem, today: now, newHash: newHash)
        let wasTargetPublished = isSemesterPublished(targetSem)

        // Move downloaded xlsx to target semester cache
        let destXLSX = cachedXLSXURL(for: targetSem)
        let fm = FileManager.default
        if fm.fileExists(atPath: destXLSX.path) {
            try? fm.removeItem(at: destXLSX)
        }
        try? fm.moveItem(at: tempXLSXURL, to: destXLSX)

        // 3. Save parsed data to per-semester JSON cache & metadata
        saveParsedDataToCache(parsed, for: targetSem)
        setSemesterHash(newHash, for: targetSem)
        setSemesterPublished(true, for: targetSem)

        // Build O(1) index bundle off the main thread before hopping to MainActor
        let prebuiltBundle = Self.buildIndexBundle(from: parsed, fallbackLastUpdated: now)

        // 4. Snapshot old target items within targetSem, update memory state, compute diff, and auto-switch if needed
        await MainActor.run {
            self.hydrationEpoch += 1
            let savedName = (self.userDefaults.string(forKey: Constants.prefSelectionName) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let savedIsGroup = (self.userDefaults.string(forKey: Constants.prefSelectionType) ?? "group") == "group"
            let existingTargetItems = self.semesterItems[targetSem] ?? []
            let shouldComputeDiff = !existingTargetItems.isEmpty && !savedName.isEmpty
            let oldTargetItems = shouldComputeDiff
                ? self.getSchedule(for: savedName, isGroup: savedIsGroup, semester: targetSem)
                : []

            self.applyBundle(prebuiltBundle, for: targetSem)
            self.semesterLastUpdated[targetSem] = now

            if targetSem == windowSem && !wasTargetPublished {
                SemesterManager.saveActiveSemester(targetSem, userDefaults: self.userDefaults)
                self.activeSemester = targetSem
            }

            self.syncPublishedStateForActiveSemester()
            if targetSem == self.activeSemester {
                self.lastUpdated = now
            }

            self.saveFastTargetCache(for: targetSem)

            if shouldComputeDiff {
                let newTargetItems = self.getSchedule(for: savedName, isGroup: savedIsGroup, semester: targetSem)
                let diff = ScheduleDiffComputer.computeDiff(
                    oldItems: oldTargetItems,
                    newItems: newTargetItems,
                    targetName: savedName,
                    isGroup: savedIsGroup
                )
                if !diff.isEmpty {
                    self.saveScheduleDiff(diff)
                }
            }

            AttendanceManager.shared.invalidateCache()
        }

        // 5. Download transfers.xlsx (optional, failure doesn't block main schedule)
        let transfersCacheURL = documentsDir.appendingPathComponent(Constants.transfersCacheFileName)
        do {
            try await NetworkService.shared.fetchTransfersFile(cacheURL: transfersCacheURL)
        } catch {
            print("Transfers fetch warning: \(error.localizedDescription)")
        }
    }

    // MARK: - Schedule Diff Persistence
    private func loadScheduleDiff() {
        guard let data = userDefaults.data(forKey: Constants.prefScheduleDiffData),
              let decoded = try? JSONDecoder().decode(ScheduleDiffResult.self, from: data),
              !decoded.isEmpty else {
            self.lastScheduleDiff = nil
            return
        }
        self.lastScheduleDiff = decoded
    }

    private func saveScheduleDiff(_ diff: ScheduleDiffResult) {
        guard !diff.isEmpty else { return }
        if let encoded = try? JSONEncoder().encode(diff) {
            userDefaults.set(encoded, forKey: Constants.prefScheduleDiffData)
        }
        self.lastScheduleDiff = diff
    }

    public func clearScheduleDiff() {
        userDefaults.removeObject(forKey: Constants.prefScheduleDiffData)
        if Thread.isMainThread {
            self.lastScheduleDiff = nil
        } else {
            DispatchQueue.main.async {
                self.lastScheduleDiff = nil
            }
        }
    }

    // MARK: - Query Schedule (O(1) Indexed Lookups)
    private func rawIndexedItems(for cleanTarget: String, isGroup: Bool, semester: SemesterType) -> [ScheduleItem] {
        if isGroup {
            return semesterGroupIndex[semester]?[cleanTarget] ?? []
        }
        if let indexed = semesterTeacherIndex[semester]?[cleanTarget], !indexed.isEmpty {
            return indexed
        }
        return items(for: semester).filter { $0.teacherName.lowercased().contains(cleanTarget) }
    }

    private static func matchesSkippedSet(_ skippedSet: Set<String>, dateString: String, lessonNumber: Int, subject: String) -> Bool {
        if skippedSet.isEmpty { return false }
        let exact = "\(dateString)#\(lessonNumber)#\(subject.trimmingCharacters(in: .whitespacesAndNewlines))"
        if skippedSet.contains(exact) { return true }
        let shortKey = "\(dateString)#\(lessonNumber)#"
        return skippedSet.contains(where: { $0.hasPrefix(shortKey) })
    }

    public func getSchedule(for targetName: String, isGroup: Bool) -> [ScheduleItem] {
        getSchedule(for: targetName, isGroup: isGroup, semester: activeSemester)
    }

    public func getSchedule(for targetName: String, isGroup: Bool, semester: SemesterType) -> [ScheduleItem] {
        let clean = targetName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return [] }

        let excluded = getExcludedSubjects(for: targetName)
        let todayStr = DateUtils.isoDateFormatter.string(from: Date())
        let skippedSet = Set(userDefaults.stringArray(forKey: Constants.prefSkippedLessons) ?? [])
        let sourceItems = rawIndexedItems(for: clean, isGroup: isGroup, semester: semester)

        return sourceItems.map { item in
            var copy = item
            if excluded.contains(item.subjectName) {
                copy.isExcluded = true
            }
            if Self.matchesSkippedSet(skippedSet, dateString: todayStr, lessonNumber: item.lessonNumber, subject: item.subjectName) {
                copy.isSkipped = true
            }
            return copy
        }
    }

    public func getAllSubjects(for groupName: String) -> [String] {
        let clean = groupName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return [] }
        var seen: [String: String] = [:]
        for semester in SemesterType.allCases {
            let groupItems = semesterGroupIndex[semester]?[clean] ?? []
            for item in groupItems {
                let sub = item.subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sub.isEmpty else { continue }
                let key = sub.lowercased()
                if seen[key] == nil {
                    seen[key] = sub
                }
            }
        }
        return seen.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // MARK: - Next Upcoming Lesson
    public func findNextLesson(
        targetName: String,
        isGroup: Bool,
        weekCalculator: WeekCalculator,
        semester: SemesterType? = nil,
        fromDate: Date = Date(),
        maxDaysAhead: Int = 14
    ) -> NextLesson? {
        let clean = targetName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }

        let targetSemester = semester ?? activeSemester
        let excluded = getExcludedSubjects(for: targetName)
        let targetItems = rawIndexedItems(for: clean, isGroup: isGroup, semester: targetSemester)
        let targetCustomEvents = getCustomEvents(for: targetName, isGroup: isGroup)
        guard !targetItems.isEmpty || !targetCustomEvents.isEmpty else { return nil }

        let skippedSet = Set(userDefaults.stringArray(forKey: Constants.prefSkippedLessons) ?? [])
        let calendar = Calendar.current
        let nowTimeStr = DateUtils.timeFormatter.string(from: fromDate)

        for dayOffset in 0...maxDaysAhead {
            guard let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: fromDate) else { continue }
            if HolidayChecker.shared.isDayOff(date: checkDate) { continue }

            let dow = DateUtils.toScheduleDayOfWeek(date: checkDate)
            guard dow >= 1 && dow <= 6 else { continue }

            let weekNum = weekCalculator.getWeekNumber(for: checkDate)
            let weekType = weekCalculator.getWeekType(for: checkDate)
            let checkDateStr = DateUtils.isoDateFormatter.string(from: checkDate)

            var dayLessons: [ScheduleItem] = []
            if weekNum > 0, let wt = weekType {
                let wtLower = wt.lowercased()
                dayLessons = targetItems.filter { item in
                    guard item.dayOfWeek == dow,
                          item.weekType.lowercased() == wtLower,
                          item.isActiveOnWeek(weekNum),
                          !item.isCancelled,
                          !excluded.contains(item.subjectName) else {
                        return false
                    }
                    return !Self.matchesSkippedSet(skippedSet, dateString: checkDateStr, lessonNumber: item.lessonNumber, subject: item.subjectName)
                }
            }

            let effectiveWeekType = weekType ?? ""
            for event in targetCustomEvents {
                if event.isRecurring && (weekNum < 1 || weekNum > SemesterManager.totalWeeks) {
                    continue
                }
                if event.matchesDate(checkDate, dayOfWeek: dow, weekType: effectiveWeekType) {
                    dayLessons.append(event.toScheduleItem(dayOfWeek: dow, isGroup: isGroup))
                }
            }

            dayLessons.sort(by: { $0.lessonNumber < $1.lessonNumber })

            let times = Constants.getLessonTimes(dayOfWeek: dow)

            for item in dayLessons {
                guard item.lessonNumber >= 1 && item.lessonNumber <= times.count else { continue }
                let timePair = times[item.lessonNumber - 1]

                if dayOffset == 0 && timePair.start <= nowTimeStr {
                    continue
                }

                return NextLesson(
                    subjectName: item.subjectName,
                    lessonType: item.lessonType,
                    room: item.room,
                    teacherOrGroup: isGroup ? item.teacherName : item.groupName,
                    date: checkDate,
                    lessonNumber: item.lessonNumber,
                    timeStart: timePair.start,
                    timeEnd: timePair.end
                )
            }
        }
        return nil
    }

    // MARK: - Teacher & Room Finder Queries (Semester-Scoped)
    public func getAllTeacherNames(semester: SemesterType? = nil) -> [String] {
        if let sem = semester, let cached = semesterTeacherDisplayNames[sem], !cached.isEmpty {
            return cached
        }

        var seen: [String: String] = [:]
        let separators = CharacterSet(charactersIn: ",;/")

        let ingest: (String) -> Void = { raw in
            for part in raw.components(separatedBy: separators) {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != "-", trimmed != "—" else { continue }
                let key = trimmed.lowercased()
                if seen[key] == nil {
                    seen[key] = trimmed
                }
            }
        }

        if let sem = semester {
            for t in semesterTeachers[sem] ?? [] { ingest(t) }
            for item in items(for: sem) { ingest(item.teacherName) }
        } else {
            for t in teachers { ingest(t) }
            if let activeNames = semesterTeacherDisplayNames[activeSemester] {
                for t in activeNames {
                    let key = t.lowercased()
                    if seen[key] == nil { seen[key] = t }
                }
            } else {
                for item in allItems { ingest(item.teacherName) }
            }
        }

        return seen.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public func getLessonsForTeacher(
        _ teacher: String,
        weekType: String,
        dayOfWeek: Int,
        semester: SemesterType? = nil
    ) -> [ScheduleItem] {
        let clean = teacher.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return [] }

        let targetSemester = semester ?? activeSemester
        let wt = weekType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sourceItems = rawIndexedItems(for: clean, isGroup: false, semester: targetSemester)
        var seenSignatures = Set<String>()

        return sourceItems.filter { item in
            !item.isCancelled &&
            item.dayOfWeek == dayOfWeek &&
            item.weekType.lowercased() == wt
        }
        .sorted { a, b in
            if a.lessonNumber != b.lessonNumber { return a.lessonNumber < b.lessonNumber }
            return a.groupName.localizedCaseInsensitiveCompare(b.groupName) == .orderedAscending
        }
        .filter { item in
            let sig = "\(item.lessonNumber)#\(item.subjectName.lowercased())#\(item.groupName.lowercased())#\(item.room.lowercased())"
            return seenSignatures.insert(sig).inserted
        }
    }

    public func getAllDistinctRooms(buildingFilter: String? = nil, semester: SemesterType? = nil) -> [String] {
        let targetSemester = semester ?? activeSemester
        let distinct = semesterDistinctRooms[targetSemester] ?? []
        guard let rawFilter = buildingFilter?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawFilter.isEmpty,
              rawFilter.caseInsensitiveCompare("Все") != .orderedSame else {
            return distinct
        }
        return distinct.filter { Self.matchesBuildingFilter($0, filter: rawFilter) }
    }

    public func getFreeRooms(
        weekType: String,
        dayOfWeek: Int,
        lessonNumber: Int,
        buildingFilter: String? = nil,
        semester: SemesterType? = nil
    ) -> [String] {
        let targetSemester = semester ?? activeSemester
        let distinctRooms = getAllDistinctRooms(buildingFilter: buildingFilter, semester: targetSemester)
        let wt = weekType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let slotKey = "\(wt)_\(dayOfWeek)_\(lessonNumber)"
        let occupied = semesterOccupiedRooms[targetSemester]?[slotKey] ?? []
        if occupied.isEmpty {
            return distinctRooms
        }
        return distinctRooms.filter { !occupied.contains($0.lowercased()) }
    }

    private static func isPhysicalRoomStatic(_ room: String) -> Bool {
        guard !room.isEmpty, room != "-", room != "—" else { return false }
        let low = room.lowercased()
        let onlineMarkers = ["онлайн", "online", "saby", "дистант", "сдо"]
        return !onlineMarkers.contains(where: { low.contains($0) })
    }

    private static func matchesBuildingFilter(_ room: String, filter: String?) -> Bool {
        guard let rawFilter = filter?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawFilter.isEmpty,
              rawFilter.caseInsensitiveCompare("Все") != .orderedSame else {
            return true
        }
        let upperRoom = room.uppercased()
        let upperFilter = rawFilter.uppercased()
        if upperFilter == "Г" {
            return upperRoom.hasPrefix("Г")
        }
        return upperRoom.hasPrefix("\(upperFilter)-") ||
            upperRoom.hasPrefix("\(upperFilter) ") ||
            upperRoom == upperFilter ||
            upperRoom.hasPrefix(upperFilter)
    }

    // MARK: - Custom Events
    public func loadCustomEvents() {
        guard let data = userDefaults.data(forKey: Constants.prefCustomEventsData),
              let list = try? JSONDecoder().decode([CustomEvent].self, from: data) else {
            self.customEvents = []
            return
        }
        self.customEvents = list
    }

    public func addCustomEvent(_ event: CustomEvent) {
        let trimmedTarget = event.targetName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubject = event.subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty, !trimmedSubject.isEmpty else { return }

        var clean = event
        clean.targetName = trimmedTarget
        clean.subjectName = trimmedSubject
        clean.lessonNumber = min(max(1, event.lessonNumber), 7)
        clean.dayOfWeek = min(max(1, event.dayOfWeek), 6)
        clean.teacherName = event.teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.room = event.room.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.note = event.note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let idx = customEvents.firstIndex(where: { $0.id == clean.id }) {
            customEvents[idx] = clean
        } else {
            customEvents.append(clean)
        }
        persistCustomEvents()
    }

    public func deleteCustomEvent(id: UUID) {
        customEvents.removeAll { $0.id == id }
        persistCustomEvents()
    }

    public func getCustomEvents(for targetName: String, isGroup: Bool) -> [CustomEvent] {
        let trimmed = targetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return customEvents.filter { event in
            event.targetName.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(trimmed) == .orderedSame &&
            event.isGroup == isGroup
        }
    }

    private func persistCustomEvents() {
        if let data = try? JSONEncoder().encode(customEvents) {
            userDefaults.set(data, forKey: Constants.prefCustomEventsData)
        }
    }

    // MARK: - Favorites
    public func loadFavorites() {
        if let data = userDefaults.data(forKey: Constants.prefFavorites),
           let list = try? JSONDecoder().decode([GroupOrTeacher].self, from: data) {
            self.favorites = list
        } else {
            self.favorites = [
                GroupOrTeacher(name: "ИВБ-24", type: .group, isFavorite: true),
                GroupOrTeacher(name: "ДТБ-23", type: .group, isFavorite: true),
                GroupOrTeacher(name: "Башкин М.А.", type: .teacher, isFavorite: true)
            ]
        }
    }

    public func isFavorite(name: String, type: SelectionType) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return favorites.contains { $0.name.lowercased() == clean && $0.type == type }
    }

    public func toggleFavorite(name: String, type: SelectionType) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = favorites.firstIndex(where: { $0.name.lowercased() == clean.lowercased() && $0.type == type }) {
            favorites.remove(at: idx)
        } else {
            favorites.append(GroupOrTeacher(name: clean, type: type, isFavorite: true))
        }
        if let data = try? JSONEncoder().encode(favorites) {
            userDefaults.set(data, forKey: Constants.prefFavorites)
        }
    }

    // MARK: - Notes (Homework / Tasks) & Photos
    public func loadNotes() {
        if let data = userDefaults.data(forKey: "lesson_notes_list"),
           let list = try? JSONDecoder().decode([LessonNote].self, from: data) {
            self.notes = list
        } else {
            self.notes = []
        }
        self.pendingNotesCount = self.notes.filter { !$0.isCompleted }.count
    }

    public func getAllNotes() -> [LessonNote] {
        notes.sorted { a, b in
            if a.isCompleted != b.isCompleted {
                return !a.isCompleted && b.isCompleted
            }
            if a.dateString != b.dateString {
                return a.dateString < b.dateString
            }
            if a.lessonNumber != b.lessonNumber {
                return a.lessonNumber < b.lessonNumber
            }
            return a.subjectName.localizedCaseInsensitiveCompare(b.subjectName) == .orderedAscending
        }
    }

    public func getNote(dateString: String, lessonNumber: Int, subject: String) -> LessonNote? {
        notes.first { $0.dateString == dateString && $0.lessonNumber == lessonNumber && $0.subjectName == subject }
    }

    public func saveNote(_ note: LessonNote) {
        if let idx = notes.firstIndex(where: {
            $0.dateString == note.dateString &&
            $0.lessonNumber == note.lessonNumber &&
            $0.subjectName == note.subjectName
        }) {
            let oldImagePath = notes[idx].imagePath
            if let oldImagePath, oldImagePath != note.imagePath {
                deleteNotePhoto(path: oldImagePath)
            }
            notes[idx] = note
        } else {
            notes.append(note)
        }
        persistNotes()
    }

    public func setNoteCompleted(date: String, lessonNumber: Int, isCompleted: Bool) {
        var changed = false
        for idx in notes.indices where notes[idx].dateString == date && notes[idx].lessonNumber == lessonNumber {
            notes[idx].isCompleted = isCompleted
            changed = true
        }
        if changed {
            persistNotes()
        }
    }

    public func setNoteCompleted(id: UUID, isCompleted: Bool) {
        if let idx = notes.firstIndex(where: { $0.id == id }) {
            notes[idx].isCompleted = isCompleted
            persistNotes()
        }
    }

    public func toggleNoteCompleted(id: UUID) {
        if let idx = notes.firstIndex(where: { $0.id == id }) {
            notes[idx].isCompleted.toggle()
            persistNotes()
        }
    }

    public func deleteNote(date: String, lessonNumber: Int) {
        let matching = notes.filter { $0.dateString == date && $0.lessonNumber == lessonNumber }
        for note in matching {
            deleteNotePhoto(path: note.imagePath)
        }
        notes.removeAll { $0.dateString == date && $0.lessonNumber == lessonNumber }
        persistNotes()
    }

    public func deleteNote(id: UUID) {
        if let existing = notes.first(where: { $0.id == id }) {
            deleteNotePhoto(path: existing.imagePath)
        }
        notes.removeAll { $0.id == id }
        persistNotes()
    }

    public func saveNotePhoto(_ data: Data) -> String? {
        let fm = FileManager.default
        if !fm.fileExists(atPath: notePhotosDir.path) {
            do {
                try fm.createDirectory(at: notePhotosDir, withIntermediateDirectories: true)
            } catch {
                return nil
            }
        }
        let filename = "\(UUID().uuidString).jpg"
        let fileURL = notePhotosDir.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    public func loadNotePhotoURL(path: String?) -> URL? {
        guard let raw = path?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let fm = FileManager.default
        if raw.hasPrefix("/") {
            if fm.fileExists(atPath: raw) {
                return URL(fileURLWithPath: raw)
            }
            let fallbackName = URL(fileURLWithPath: raw).lastPathComponent
            let fallbackURL = notePhotosDir.appendingPathComponent(fallbackName)
            return fm.fileExists(atPath: fallbackURL.path) ? fallbackURL : nil
        }
        let url = notePhotosDir.appendingPathComponent(raw)
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    public func deleteNotePhoto(path: String?) {
        guard let url = loadNotePhotoURL(path: path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func persistNotes() {
        self.pendingNotesCount = notes.filter { !$0.isCompleted }.count
        if let data = try? JSONEncoder().encode(notes) {
            userDefaults.set(data, forKey: "lesson_notes_list")
        }
    }

    // MARK: - Clear All Data
    public func clearAllData() {
        hydrationEpoch += 1
        let fm = FileManager.default
        for semester in SemesterType.allCases {
            try? fm.removeItem(at: cacheFileURL(for: semester))
            try? fm.removeItem(at: cachedXLSXURL(for: semester))
            try? fm.removeItem(at: fastTargetCacheURL(for: semester))
            userDefaults.removeObject(forKey: Constants.prefSemesterHashPrefix + semester.rawValue)
            userDefaults.removeObject(forKey: Constants.prefSemesterPublishedPrefix + semester.rawValue)
            userDefaults.removeObject(forKey: Constants.prefSemesterStartPrefix + semester.rawValue)
        }
        try? fm.removeItem(at: legacyCacheFileURL)
        try? fm.removeItem(at: legacyCachedXLSXURL)
        try? fm.removeItem(at: notePhotosDir)

        userDefaults.removeObject(forKey: Constants.prefCustomEventsData)
        userDefaults.removeObject(forKey: "lesson_notes_list")
        userDefaults.removeObject(forKey: Constants.prefScheduleDiffData)
        userDefaults.removeObject(forKey: Constants.prefLastUpdated)
        userDefaults.removeObject(forKey: Constants.prefSemesterStart)
        userDefaults.removeObject(forKey: Constants.prefActiveSemester)

        customEvents = []
        notes = []
        pendingNotesCount = 0
        lastScheduleDiff = nil
        lastUpdated = nil
        activeSemester = SemesterManager.getCurrentWindowSemester()
        AttendanceManager.shared.invalidateCache()

        loadFromCacheOrBundle()
    }

    // MARK: - Attendance & Skipped Lessons ("Н-ки" и "Посещено")
    private func buildAttendanceKey(dateString: String, lessonNumber: Int, subject: String) -> String {
        return "\(dateString)#\(lessonNumber)#\(subject.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    public func isLessonSkipped(dateString: String, lessonNumber: Int, subject: String) -> Bool {
        let set = Set(userDefaults.stringArray(forKey: Constants.prefSkippedLessons) ?? [])
        let exact = buildAttendanceKey(dateString: dateString, lessonNumber: lessonNumber, subject: subject)
        if set.contains(exact) { return true }
        let shortKey = "\(dateString)#\(lessonNumber)#"
        return set.contains(where: { $0.hasPrefix(shortKey) })
    }

    public func isLessonAttended(dateString: String, lessonNumber: Int, subject: String) -> Bool {
        let set = Set(userDefaults.stringArray(forKey: Constants.prefAttendedLessons) ?? [])
        let exact = buildAttendanceKey(dateString: dateString, lessonNumber: lessonNumber, subject: subject)
        if set.contains(exact) { return true }
        let shortKey = "\(dateString)#\(lessonNumber)#"
        return set.contains(where: { $0.hasPrefix(shortKey) })
    }

    public func getAttendanceStatus(dateString: String, lessonNumber: Int, subject: String) -> AttendanceStatus {
        if isLessonSkipped(dateString: dateString, lessonNumber: lessonNumber, subject: subject) {
            return .skipped
        }
        if isLessonAttended(dateString: dateString, lessonNumber: lessonNumber, subject: subject) {
            return .attended
        }
        return .none
    }

    public func markLessonSkipped(dateString: String, lessonNumber: Int, subject: String) {
        let exact = buildAttendanceKey(dateString: dateString, lessonNumber: lessonNumber, subject: subject)
        let shortKey = "\(dateString)#\(lessonNumber)#"

        var skippedSet = Set(userDefaults.stringArray(forKey: Constants.prefSkippedLessons) ?? [])
        var attendedSet = Set(userDefaults.stringArray(forKey: Constants.prefAttendedLessons) ?? [])

        skippedSet = skippedSet.filter { $0 != exact && !$0.hasPrefix(shortKey) }
        attendedSet = attendedSet.filter { $0 != exact && !$0.hasPrefix(shortKey) }

        skippedSet.insert(exact)
        userDefaults.set(Array(skippedSet), forKey: Constants.prefSkippedLessons)
        userDefaults.set(Array(attendedSet), forKey: Constants.prefAttendedLessons)
        AttendanceManager.shared.invalidateCache()
        NotificationCenter.default.post(name: NSNotification.Name("AttendanceChanged"), object: nil)
    }

    public func markLessonAttended(dateString: String, lessonNumber: Int, subject: String) {
        let exact = buildAttendanceKey(dateString: dateString, lessonNumber: lessonNumber, subject: subject)
        let shortKey = "\(dateString)#\(lessonNumber)#"

        var skippedSet = Set(userDefaults.stringArray(forKey: Constants.prefSkippedLessons) ?? [])
        var attendedSet = Set(userDefaults.stringArray(forKey: Constants.prefAttendedLessons) ?? [])

        skippedSet = skippedSet.filter { $0 != exact && !$0.hasPrefix(shortKey) }
        attendedSet = attendedSet.filter { $0 != exact && !$0.hasPrefix(shortKey) }

        attendedSet.insert(exact)
        userDefaults.set(Array(skippedSet), forKey: Constants.prefSkippedLessons)
        userDefaults.set(Array(attendedSet), forKey: Constants.prefAttendedLessons)
        AttendanceManager.shared.invalidateCache()
        NotificationCenter.default.post(name: NSNotification.Name("AttendanceChanged"), object: nil)
    }

    public func clearLessonAttendance(dateString: String, lessonNumber: Int, subject: String) {
        let exact = buildAttendanceKey(dateString: dateString, lessonNumber: lessonNumber, subject: subject)
        let shortKey = "\(dateString)#\(lessonNumber)#"

        var skippedSet = Set(userDefaults.stringArray(forKey: Constants.prefSkippedLessons) ?? [])
        var attendedSet = Set(userDefaults.stringArray(forKey: Constants.prefAttendedLessons) ?? [])

        skippedSet = skippedSet.filter { $0 != exact && !$0.hasPrefix(shortKey) }
        attendedSet = attendedSet.filter { $0 != exact && !$0.hasPrefix(shortKey) }

        userDefaults.set(Array(skippedSet), forKey: Constants.prefSkippedLessons)
        userDefaults.set(Array(attendedSet), forKey: Constants.prefAttendedLessons)
        AttendanceManager.shared.invalidateCache()
        NotificationCenter.default.post(name: NSNotification.Name("AttendanceChanged"), object: nil)
    }

    public func toggleLessonSkipped(dateString: String, lessonNumber: Int, subject: String) -> Bool {
        if isLessonSkipped(dateString: dateString, lessonNumber: lessonNumber, subject: subject) {
            clearLessonAttendance(dateString: dateString, lessonNumber: lessonNumber, subject: subject)
            return false
        } else {
            markLessonSkipped(dateString: dateString, lessonNumber: lessonNumber, subject: subject)
            return true
        }
    }

    // Manual adjustments (+/- skips for subject)
    public func getManualAdjustment(group: String, subject: String) -> Int {
        let key = "\(Constants.prefAttendanceManualPrefix)\(group.trimmingCharacters(in: .whitespacesAndNewlines))_\(subject.trimmingCharacters(in: .whitespacesAndNewlines))"
        return userDefaults.integer(forKey: key)
    }

    public func adjustManualSkips(group: String, subject: String, delta: Int) {
        let key = "\(Constants.prefAttendanceManualPrefix)\(group.trimmingCharacters(in: .whitespacesAndNewlines))_\(subject.trimmingCharacters(in: .whitespacesAndNewlines))"
        let current = userDefaults.integer(forKey: key)
        userDefaults.set(current + delta, forKey: key)
        AttendanceManager.shared.invalidateCache()
        NotificationCenter.default.post(name: NSNotification.Name("AttendanceChanged"), object: nil)
    }

    // MARK: - Excluded Subjects ("Перезачёт")
    public func isSubjectExcluded(group: String, subject: String) -> Bool {
        let key = Constants.prefExcludedSubjectsPrefix + group.trimmingCharacters(in: .whitespacesAndNewlines)
        let set = Set(userDefaults.stringArray(forKey: key) ?? [])
        return set.contains(subject.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public func getExcludedSubjects(for group: String) -> Set<String> {
        let key = Constants.prefExcludedSubjectsPrefix + group.trimmingCharacters(in: .whitespacesAndNewlines)
        return Set(userDefaults.stringArray(forKey: key) ?? [])
    }

    public func toggleExcludedSubject(group: String, subject: String) {
        let key = Constants.prefExcludedSubjectsPrefix + group.trimmingCharacters(in: .whitespacesAndNewlines)
        var set = getExcludedSubjects(for: group)
        if set.contains(subject) {
            set.remove(subject)
        } else {
            set.insert(subject)
        }
        userDefaults.set(Array(set), forKey: key)
        AttendanceManager.shared.invalidateCache()
        NotificationCenter.default.post(name: NSNotification.Name("AttendanceChanged"), object: nil)
    }
}
