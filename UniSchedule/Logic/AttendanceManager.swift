import Foundation

public enum BudgetHealth: String, Codable, Equatable {
    case safe
    case warning
    case exceeded
}

public final class AttendanceManager {
    public static let shared = AttendanceManager()
    public static let defaultWarningThreshold = 3
    public static let validSkipLimits = [20, 25, 30]
    
    private let userDefaults: UserDefaults
    private var cachedReports: [SemesterType: (key: String, manualSnapshot: [String: Int], report: AttendanceReport)] = [:]
    private let cacheLock = NSLock()

    public func invalidateCache() {
        cacheLock.lock()
        cachedReports.removeAll()
        cacheLock.unlock()
    }
    
    public var skipLimitPercent: Int {
        get {
            let stored = userDefaults.integer(forKey: Constants.prefAttendanceSkipLimitPct)
            return Self.validSkipLimits.contains(stored) ? stored : 30
        }
        set {
            let validated = Self.validSkipLimits.contains(newValue) ? newValue : 30
            userDefaults.set(validated, forKey: Constants.prefAttendanceSkipLimitPct)
        }
    }
    
    public struct SubjectAttendance: Identifiable, Equatable {
        public var id: String { subjectName }
        public let subjectName: String
        public var totalPlanned: Int
        public var missedCount: Int
        public var attendedCount: Int
        public var attendancePercent: Int
        public var skipPercent: Int
        public var maxAllowedSkips: Int
        public var remainingBudget: Int
        public var budgetHealth: BudgetHealth
        
        public var hasWarning: Bool {
            missedCount >= AttendanceManager.defaultWarningThreshold
        }
        
        public init(
            subjectName: String,
            totalPlanned: Int = 0,
            missedCount: Int = 0,
            attendedCount: Int = 0,
            attendancePercent: Int = 100,
            skipPercent: Int = 0,
            maxAllowedSkips: Int = 0,
            remainingBudget: Int = 0,
            budgetHealth: BudgetHealth = .safe
        ) {
            self.subjectName = subjectName
            self.totalPlanned = totalPlanned
            self.missedCount = missedCount
            self.attendedCount = attendedCount
            self.attendancePercent = attendancePercent
            self.skipPercent = skipPercent
            self.maxAllowedSkips = maxAllowedSkips
            self.remainingBudget = remainingBudget
            self.budgetHealth = budgetHealth
        }
    }
    
    public struct OverallAttendance: Equatable {
        public var totalPlanned: Int = 0
        public var missedCount: Int = 0
        public var attendedCount: Int = 0
        public var attendancePercent: Int = 100
        public var skipPercent: Int = 0
        public var maxAllowedSkips: Int = 0
        public var remainingBudget: Int = 0
        public var budgetHealth: BudgetHealth = .safe
        public var limitPercent: Int = 30
        
        public init(
            totalPlanned: Int = 0,
            missedCount: Int = 0,
            attendedCount: Int = 0,
            attendancePercent: Int = 100,
            skipPercent: Int = 0,
            maxAllowedSkips: Int = 0,
            remainingBudget: Int = 0,
            budgetHealth: BudgetHealth = .safe,
            limitPercent: Int = 30
        ) {
            self.totalPlanned = totalPlanned
            self.missedCount = missedCount
            self.attendedCount = attendedCount
            self.attendancePercent = attendancePercent
            self.skipPercent = skipPercent
            self.maxAllowedSkips = maxAllowedSkips
            self.remainingBudget = remainingBudget
            self.budgetHealth = budgetHealth
            self.limitPercent = limitPercent
        }
    }
    
    public struct AttendanceReport: Equatable {
        public let overall: OverallAttendance
        public let subjects: [SubjectAttendance]
        
        public init(overall: OverallAttendance, subjects: [SubjectAttendance]) {
            self.overall = overall
            self.subjects = subjects
        }
    }
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - Russian Skips & Lessons Plural Formatting
    public static func formatSkips(_ count: Int) -> String {
        let rem100 = count % 100
        let rem10 = count % 10
        if rem100 >= 11 && rem100 <= 19 {
            return "\(count) Н-ок"
        }
        if rem10 == 1 {
            return "\(count) Н-ка"
        }
        if rem10 >= 2 && rem10 <= 4 {
            return "\(count) Н-ки"
        }
        return "\(count) Н-ок"
    }
    
    public static func formatLessonsCount(_ count: Int) -> String {
        let absCount = abs(count)
        let rem100 = absCount % 100
        let rem10 = absCount % 10
        if rem100 >= 11 && rem100 <= 19 {
            return "\(count) пар"
        }
        if rem10 == 1 {
            return "\(count) пара"
        }
        if rem10 >= 2 && rem10 <= 4 {
            return "\(count) пары"
        }
        return "\(count) пар"
    }
    
    // MARK: - Skip Budget Math
    public static func computeSkipPercent(missed: Int, planned: Int) -> Int {
        guard planned > 0, missed > 0 else { return 0 }
        return Int((Double(missed) * 100.0 / Double(planned)).rounded())
    }
    
    public static func computeMaxAllowedSkips(planned: Int, limitPct: Int) -> Int {
        guard planned > 0, limitPct > 0 else { return 0 }
        return Int(floor(Double(planned) * Double(limitPct) / 100.0))
    }
    
    public static func computeRemainingSkipBudget(missed: Int, planned: Int, limitPct: Int) -> Int {
        computeMaxAllowedSkips(planned: planned, limitPct: limitPct) - max(0, missed)
    }
    
    public static func evaluateBudgetHealth(missed: Int, planned: Int, limitPct: Int) -> BudgetHealth {
        guard planned > 0 else { return .safe }
        let remaining = computeRemainingSkipBudget(missed: missed, planned: planned, limitPct: limitPct)
        if remaining < 0 { return .exceeded }
        if remaining == 1 || (remaining == 0 && missed > 0) { return .warning }
        return .safe
    }
    
    public static func formatBudgetStatus(missed: Int, planned: Int, limitPct: Int) -> String {
        guard planned > 0 else { return "Нет проведённых пар" }
        let skipPct = computeSkipPercent(missed: missed, planned: planned)
        let remaining = computeRemainingSkipBudget(missed: missed, planned: planned, limitPct: limitPct)
        if remaining < 0 {
            return "Лимит превышен! (\(skipPct)%)"
        }
        if remaining == 1 {
            return "Последний запас: 1 пара"
        }
        if remaining == 0 && missed <= 0 {
            return "Пропусков нет · запас 0 пар"
        }
        if remaining == 0 && missed > 0 {
            return "Запас исчерпан (\(skipPct)%)"
        }
        return "Можно пропустить ещё \(formatLessonsCount(remaining))"
    }
    
    // MARK: - Calculate Attendance Report
    public func calculateReport(
        groupName: String,
        semester: SemesterType = SemesterManager.loadActiveSemester(),
        repository: ScheduleRepository = .shared,
        weekCalculator: WeekCalculator? = nil,
        holidayChecker: HolidayChecker = .shared,
        allTransfers: [TransferItem] = [],
        today: Date = Date()
    ) -> AttendanceReport {
        let limitPct = skipLimitPercent
        let cleanGroup = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanGroup.isEmpty else {
            return AttendanceReport(overall: OverallAttendance(limitPercent: limitPct), subjects: [])
        }

        let calc = weekCalculator ?? WeekCalculator(semesterStartDate: SemesterManager.loadSemesterStart(for: semester))
        let calendar = Calendar.current
        let semesterStart = calendar.startOfDay(for: calc.semesterStartDate)
        let todayStart = calendar.startOfDay(for: today)

        let allItems = repository.getSchedule(for: cleanGroup, isGroup: true, semester: semester)
            .filter { !$0.isCustom }
        let excluded = repository.getExcludedSubjects(for: cleanGroup)
        let skippedSet = Set(userDefaults.stringArray(forKey: Constants.prefSkippedLessons) ?? [])
        let attendedSet = Set(userDefaults.stringArray(forKey: Constants.prefAttendedLessons) ?? [])

        let cacheKey = [
            cleanGroup.lowercased(),
            semester.rawValue,
            DateUtils.isoDateFormatter.string(from: semesterStart),
            DateUtils.isoDateFormatter.string(from: todayStart),
            String(limitPct),
            String(allItems.count),
            String(allTransfers.count),
            String(excluded.sorted().joined(separator: "|").hashValue),
            String(skippedSet.sorted().joined(separator: "|").hashValue),
            String(attendedSet.sorted().joined(separator: "|").hashValue)
        ].joined(separator: "#")

        cacheLock.lock()
        if let hit = cachedReports[semester], hit.key == cacheKey {
            let manualMatch = hit.manualSnapshot.allSatisfy { subject, expectedAdj in
                repository.getManualAdjustment(group: cleanGroup, subject: subject) == expectedAdj
            }
            if manualMatch {
                cacheLock.unlock()
                return hit.report
            }
        }
        cacheLock.unlock()

        var statsMap: [String: SubjectAttendance] = [:]

        // Scan Mon–Sat from semesterStart up to min(semesterEnd, today + 14 days) across weeks 1...18
        let totalDays = SemesterManager.totalWeeks * 7
        guard let semesterEnd = calendar.date(byAdding: .day, value: totalDays - 1, to: semesterStart),
              let horizon = calendar.date(byAdding: .day, value: 14, to: todayStart) else {
            return AttendanceReport(overall: OverallAttendance(limitPercent: limitPct), subjects: [])
        }
        let scanEnd = min(semesterEnd, horizon)
        guard semesterStart <= scanEnd else {
            return AttendanceReport(overall: OverallAttendance(limitPercent: limitPct), subjects: [])
        }

        // Batch index base schedule items by (dayOfWeek, weekTypeLower)
        struct SlotKey: Hashable {
            let dow: Int
            let weekType: String
        }
        var itemsBySlot: [SlotKey: [ScheduleItem]] = [:]
        for item in allItems where !item.isCancelled {
            let key = SlotKey(dow: item.dayOfWeek, weekType: item.weekType.lowercased())
            itemsBySlot[key, default: []].append(item)
        }

        // Batch index transfers for this group in [semesterStart, scanEnd]
        var removalsByDate: [String: [Int: Int]] = [:]
        var additionsByDate: [String: [TransferItem]] = [:]
        for transfer in allTransfers where transfer.matchesGroup(cleanGroup) {
            switch transfer.type {
            case .removal:
                if let rd = transfer.removalDate, let rl = transfer.removalLesson {
                    let rdStart = calendar.startOfDay(for: rd)
                    if rdStart >= semesterStart && rdStart <= scanEnd {
                        let dStr = DateUtils.isoDateFormatter.string(from: rdStart)
                        removalsByDate[dStr, default: [:]][rl, default: 0] += 1
                    }
                }
            case .addition:
                if let ad = transfer.additionDate, transfer.additionLesson != nil {
                    let adStart = calendar.startOfDay(for: ad)
                    if adStart >= semesterStart && adStart <= scanEnd {
                        let dStr = DateUtils.isoDateFormatter.string(from: adStart)
                        additionsByDate[dStr, default: []].append(transfer)
                    }
                }
            case .roomChange:
                break
            }
        }

        for dayOffset in 0..<totalDays {
            guard let cursor = calendar.date(byAdding: .day, value: dayOffset, to: semesterStart) else { continue }
            let cursorStart = calendar.startOfDay(for: cursor)
            if cursorStart > scanEnd { break }

            // Skip official holidays and Sundays
            if holidayChecker.isDayOff(date: cursor) { continue }
            let dow = DateUtils.toScheduleDayOfWeek(date: cursor)
            guard dow >= 1 && dow <= 6 else { continue }

            let weekNum = calc.getWeekNumber(for: cursor)
            guard weekNum >= 1 && weekNum <= SemesterManager.totalWeeks else { continue }
            let weekType = calc.isEvenWeek(weekNum) ? Constants.weekTypeEven : Constants.weekTypeOdd

            let isFuture = cursorStart > todayStart
            let dateStr = DateUtils.isoDateFormatter.string(from: cursor)
            var dayRemovals = removalsByDate[dateStr] ?? [:]

            let slotItems = itemsBySlot[SlotKey(dow: dow, weekType: weekType.lowercased())] ?? []
            for item in slotItems {
                if !item.isActiveOnWeek(weekNum) { continue }

                if let remCount = dayRemovals[item.lessonNumber], remCount > 0 {
                    dayRemovals[item.lessonNumber] = remCount - 1
                    continue
                }

                let sub = item.subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                if sub.isEmpty || excluded.contains(sub) { continue }

                let isSkipped = Self.matchesAttendance(set: skippedSet, dateString: dateStr, lessonNumber: item.lessonNumber, subject: sub)
                let isAttended = Self.matchesAttendance(set: attendedSet, dateString: dateStr, lessonNumber: item.lessonNumber, subject: sub)

                if isFuture && !isSkipped && !isAttended {
                    continue
                }

                var sa = statsMap[sub] ?? SubjectAttendance(subjectName: sub)
                sa.totalPlanned += 1
                if isSkipped {
                    sa.missedCount += 1
                } else {
                    sa.attendedCount += 1
                }
                statsMap[sub] = sa
            }

            if let dayAdditions = additionsByDate[dateStr] {
                for add in dayAdditions {
                    guard let lessonNum = add.additionLesson else { continue }
                    let sub = add.subject.trimmingCharacters(in: .whitespacesAndNewlines)
                    if sub.isEmpty || excluded.contains(sub) { continue }

                    let isSkipped = Self.matchesAttendance(set: skippedSet, dateString: dateStr, lessonNumber: lessonNum, subject: sub)
                    let isAttended = Self.matchesAttendance(set: attendedSet, dateString: dateStr, lessonNumber: lessonNum, subject: sub)

                    if isFuture && !isSkipped && !isAttended {
                        continue
                    }

                    var sa = statsMap[sub] ?? SubjectAttendance(subjectName: sub)
                    sa.totalPlanned += 1
                    if isSkipped {
                        sa.missedCount += 1
                    } else {
                        sa.attendedCount += 1
                    }
                    statsMap[sub] = sa
                }
            }
        }

        // Apply manual adjustments and calculate percentages & skip budget
        var totalPlannedAll = 0
        var totalMissedAll = 0
        var updatedSubjects: [SubjectAttendance] = []

        var manualSnapshot: [String: Int] = [:]
        for var sa in statsMap.values {
            let adj = repository.getManualAdjustment(group: cleanGroup, subject: sa.subjectName)
            manualSnapshot[sa.subjectName] = adj
            sa.missedCount = max(0, sa.missedCount + adj)
            if sa.missedCount > sa.totalPlanned && sa.totalPlanned > 0 {
                sa.totalPlanned = sa.missedCount
            }
            sa.attendedCount = max(0, sa.totalPlanned - sa.missedCount)
            sa.attendancePercent = sa.totalPlanned > 0
                ? Int(round(Float(sa.attendedCount) * 100.0 / Float(sa.totalPlanned)))
                : 100
            sa.skipPercent = Self.computeSkipPercent(missed: sa.missedCount, planned: sa.totalPlanned)
            sa.maxAllowedSkips = Self.computeMaxAllowedSkips(planned: sa.totalPlanned, limitPct: limitPct)
            sa.remainingBudget = Self.computeRemainingSkipBudget(missed: sa.missedCount, planned: sa.totalPlanned, limitPct: limitPct)
            sa.budgetHealth = Self.evaluateBudgetHealth(missed: sa.missedCount, planned: sa.totalPlanned, limitPct: limitPct)

            totalPlannedAll += sa.totalPlanned
            totalMissedAll += sa.missedCount
            updatedSubjects.append(sa)
        }

        // Sort subjects: most skips first, then alphabetical
        updatedSubjects.sort { a, b in
            if a.missedCount != b.missedCount {
                return a.missedCount > b.missedCount
            }
            return a.subjectName.localizedCaseInsensitiveCompare(b.subjectName) == .orderedAscending
        }

        let attendedAll = max(0, totalPlannedAll - totalMissedAll)
        let percentAll = totalPlannedAll > 0
            ? Int(round(Float(attendedAll) * 100.0 / Float(totalPlannedAll)))
            : 100

        let overall = OverallAttendance(
            totalPlanned: totalPlannedAll,
            missedCount: totalMissedAll,
            attendedCount: attendedAll,
            attendancePercent: percentAll,
            skipPercent: Self.computeSkipPercent(missed: totalMissedAll, planned: totalPlannedAll),
            maxAllowedSkips: Self.computeMaxAllowedSkips(planned: totalPlannedAll, limitPct: limitPct),
            remainingBudget: Self.computeRemainingSkipBudget(missed: totalMissedAll, planned: totalPlannedAll, limitPct: limitPct),
            budgetHealth: Self.evaluateBudgetHealth(missed: totalMissedAll, planned: totalPlannedAll, limitPct: limitPct),
            limitPercent: limitPct
        )

        let report = AttendanceReport(overall: overall, subjects: updatedSubjects)
        cacheLock.lock()
        cachedReports[semester] = (key: cacheKey, manualSnapshot: manualSnapshot, report: report)
        cacheLock.unlock()
        return report
    }

    private static func matchesAttendance(set: Set<String>, dateString: String, lessonNumber: Int, subject: String) -> Bool {
        let exact = "\(dateString)#\(lessonNumber)#\(subject.trimmingCharacters(in: .whitespacesAndNewlines))"
        if set.contains(exact) { return true }
        let shortKey = "\(dateString)#\(lessonNumber)#"
        return set.contains(where: { $0.hasPrefix(shortKey) })
    }

    // MARK: - Warning for Subject
    public func getWarningForSubject(
        _ subjectName: String,
        groupName: String,
        semester: SemesterType = SemesterManager.loadActiveSemester(),
        repository: ScheduleRepository = .shared
    ) -> String? {
        let sub = subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { return nil }
        let report = calculateReport(groupName: groupName, semester: semester, repository: repository)
        if let sa = report.subjects.first(where: { $0.subjectName.caseInsensitiveCompare(sub) == .orderedSame }), sa.hasWarning {
            return "🟡 Внимание: уже \(AttendanceManager.formatSkips(sa.missedCount)), пора ходить!"
        }
        return nil
    }
}
