import Foundation

public final class AttendanceManager {
    public static let shared = AttendanceManager()
    public static let defaultWarningThreshold = 3
    
    public struct SubjectAttendance: Identifiable, Equatable {
        public var id: String { subjectName }
        public let subjectName: String
        public var totalPlanned: Int
        public var missedCount: Int
        public var attendedCount: Int
        public var attendancePercent: Int
        
        public var hasWarning: Bool {
            missedCount >= AttendanceManager.defaultWarningThreshold
        }
        
        public init(
            subjectName: String,
            totalPlanned: Int = 0,
            missedCount: Int = 0,
            attendedCount: Int = 0,
            attendancePercent: Int = 100
        ) {
            self.subjectName = subjectName
            self.totalPlanned = totalPlanned
            self.missedCount = missedCount
            self.attendedCount = attendedCount
            self.attendancePercent = attendancePercent
        }
    }
    
    public struct OverallAttendance: Equatable {
        public var totalPlanned: Int = 0
        public var missedCount: Int = 0
        public var attendedCount: Int = 0
        public var attendancePercent: Int = 100
        
        public init(
            totalPlanned: Int = 0,
            missedCount: Int = 0,
            attendedCount: Int = 0,
            attendancePercent: Int = 100
        ) {
            self.totalPlanned = totalPlanned
            self.missedCount = missedCount
            self.attendedCount = attendedCount
            self.attendancePercent = attendancePercent
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
    
    public init() {}
    
    // MARK: - Russian Skips Plural Formatting
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
    
    // MARK: - Calculate Attendance Report
    public func calculateReport(
        groupName: String,
        repository: ScheduleRepository = .shared,
        weekCalculator: WeekCalculator = WeekCalculator(),
        holidayChecker: HolidayChecker = .shared,
        today: Date = Date()
    ) -> AttendanceReport {
        guard !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AttendanceReport(overall: OverallAttendance(), subjects: [])
        }
        
        let allItems = repository.getSchedule(for: groupName, isGroup: true)
        let excluded = repository.getExcludedSubjects(for: groupName)
        
        let calendar = Calendar.current
        let semesterStart = SemesterManager.loadSemesterStart()
        let todayStart = calendar.startOfDay(for: today)
        
        var statsMap: [String: SubjectAttendance] = [:]
        
        // Scan each day of the semester up to 18 weeks from start
        let totalDays = SemesterManager.totalWeeks * 7
        
        for dayOffset in 0..<totalDays {
            guard let cursor = calendar.date(byAdding: .day, value: dayOffset, to: semesterStart) else { continue }
            let cursorStart = calendar.startOfDay(for: cursor)
            
            // Skip official holidays and Sundays
            if holidayChecker.isDayOff(date: cursor) { continue }
            let dow = DateUtils.toScheduleDayOfWeek(date: cursor)
            guard dow >= 1 && dow <= 6 else { continue }
            
            let weekNum = weekCalculator.getWeekNumber(for: cursor)
            guard weekNum > 0 else { continue }
            let weekType = weekCalculator.isEvenWeek(weekNum) ? Constants.weekTypeEven : Constants.weekTypeOdd
            
            let isFuture = cursorStart > todayStart
            let dateStr = DateUtils.isoDateFormatter.string(from: cursor)
            
            for item in allItems {
                if item.dayOfWeek != dow { continue }
                if item.weekType.lowercased() != weekType.lowercased() { continue }
                if item.isCancelled { continue }
                if !item.isActiveOnWeek(weekNum) { continue }
                
                let sub = item.subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                if sub.isEmpty || excluded.contains(sub) { continue }
                
                let isSkipped = repository.isLessonSkipped(dateString: dateStr, lessonNumber: item.lessonNumber, subject: sub)
                let isAttended = repository.isLessonAttended(dateString: dateStr, lessonNumber: item.lessonNumber, subject: sub)
                
                // Future lessons are counted only if marked in advance
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
        
        // Apply manual adjustments and calculate percentages
        var totalPlannedAll = 0
        var totalMissedAll = 0
        var updatedSubjects: [SubjectAttendance] = []
        
        for var sa in statsMap.values {
            let adj = repository.getManualAdjustment(group: groupName, subject: sa.subjectName)
            sa.missedCount = max(0, sa.missedCount + adj)
            if sa.missedCount > sa.totalPlanned && sa.totalPlanned > 0 {
                sa.totalPlanned = sa.missedCount
            }
            sa.attendedCount = max(0, sa.totalPlanned - sa.missedCount)
            sa.attendancePercent = sa.totalPlanned > 0
                ? Int(round(Float(sa.attendedCount) * 100.0 / Float(sa.totalPlanned)))
                : 100
            
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
            attendancePercent: percentAll
        )
        
        return AttendanceReport(overall: overall, subjects: updatedSubjects)
    }
    
    // MARK: - Warning for Subject
    public func getWarningForSubject(
        _ subjectName: String,
        groupName: String,
        repository: ScheduleRepository = .shared
    ) -> String? {
        let sub = subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { return nil }
        let report = calculateReport(groupName: groupName, repository: repository)
        if let sa = report.subjects.first(where: { $0.subjectName.caseInsensitiveCompare(sub) == .orderedSame }), sa.hasWarning {
            return "🟡 Внимание: уже \(AttendanceManager.formatSkips(sa.missedCount)), пора ходить!"
        }
        return nil
    }
}
