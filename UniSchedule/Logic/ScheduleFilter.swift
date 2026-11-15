import Foundation

public final class ScheduleFilter {
    private let holidayChecker: HolidayChecker
    
    public init(holidayChecker: HolidayChecker = .shared) {
        self.holidayChecker = holidayChecker
    }
    
    public func buildWeekSchedule(
        allItems: [ScheduleItem],
        weekNumber: Int,
        weekType: String,
        mondayOfWeek: Date,
        allTransfers: [TransferItem] = [],
        targetName: String = "",
        isGroup: Bool = true
    ) -> WeekSchedule {
        let isEven = (weekType == Constants.weekTypeEven)
        var days: [DaySchedule] = []
        
        for dow in 1...6 {
            let date = DateUtils.dateForDayInWeek(monday: mondayOfWeek, dayOfWeek: dow)
            var day = DaySchedule(dayOfWeek: dow, date: date)
            
            if holidayChecker.isDayOff(date: date) {
                day.isDayOff = true
                day.holidayName = holidayChecker.getHolidayName(date: date)
            }
            
            var lessons = filterLessonsForDay(allItems: allItems, dayOfWeek: dow, weekType: weekType, weekNumber: weekNumber)
            
            let dayTransfers = filterTransfers(transfers: allTransfers, forDate: date, targetName: targetName, isGroup: isGroup)
            if !dayTransfers.isEmpty {
                lessons = mergeTransfers(lessons: lessons, transfers: dayTransfers, date: date, dow: dow, weekType: weekType)
            }
            
            // Decorate with dynamic attendance status & exclusion for this specific date
            let dateStr = DateUtils.isoDateFormatter.string(from: date)
            let repo = ScheduleRepository.shared
            let excluded = repo.getExcludedSubjects(for: targetName)
            
            lessons = lessons.map { item in
                var copy = item
                if excluded.contains(item.subjectName) {
                    copy.isExcluded = true
                }
                let status = repo.getAttendanceStatus(dateString: dateStr, lessonNumber: item.lessonNumber, subject: item.subjectName)
                copy.isSkipped = (status == .skipped)
                copy.isAttended = (status == .attended)
                return copy
            }
            
            // Sort by lesson number
            day.lessons = lessons.sorted(by: { $0.lessonNumber < $1.lessonNumber })
            days.append(day)
        }
        
        return WeekSchedule(weekNumber: weekNumber, isEven: isEven, days: days)
    }
    
    public func filterLessonsForDay(
        allItems: [ScheduleItem],
        dayOfWeek: Int,
        weekType: String,
        weekNumber: Int
    ) -> [ScheduleItem] {
        allItems.filter { item in
            item.dayOfWeek == dayOfWeek &&
            item.weekType.lowercased() == weekType.lowercased() &&
            item.isActiveOnWeek(weekNumber)
        }.sorted { $0.lessonNumber < $1.lessonNumber }
    }
    
    public func filterTransfers(
        transfers: [TransferItem],
        forDate date: Date,
        targetName: String,
        isGroup: Bool
    ) -> [TransferItem] {
        let cal = Calendar.current
        let targetDay = cal.startOfDay(for: date)
        
        return transfers.filter { item in
            let matches = isGroup ? item.matchesGroup(targetName) : item.matchesTeacher(targetName)
            guard matches else { return false }
            
            if let rd = item.removalDate, cal.startOfDay(for: rd) == targetDay {
                return true
            }
            if let ad = item.additionDate, cal.startOfDay(for: ad) == targetDay {
                return true
            }
            return false
        }
    }
    
    public func mergeTransfers(
        lessons: [ScheduleItem],
        transfers: [TransferItem],
        date: Date,
        dow: Int,
        weekType: String
    ) -> [ScheduleItem] {
        var result = lessons
        let cal = Calendar.current
        let targetDay = cal.startOfDay(for: date)
        
        for transfer in transfers {
            switch transfer.type {
            case .removal:
                if let rd = transfer.removalDate, cal.startOfDay(for: rd) == targetDay {
                    for i in 0..<result.count {
                        if result[i].lessonNumber == transfer.removalLesson {
                            result[i].isCancelled = true
                            if let ad = transfer.additionDate, let al = transfer.additionLesson {
                                result[i].transferNote = "Перенесено на \(DateUtils.formatDisplayDateShort(ad)), \(al) пара"
                            } else {
                                result[i].transferNote = "Занятие отменено"
                            }
                        }
                    }
                }
                
            case .addition:
                if let ad = transfer.additionDate, cal.startOfDay(for: ad) == targetDay,
                   let lessonNum = transfer.additionLesson {
                    var note = "Перенос"
                    if let rd = transfer.removalDate, let rl = transfer.removalLesson {
                        note = "Перенесено с \(DateUtils.formatDisplayDateShort(rd)), \(rl) пара"
                    }
                    let newItem = ScheduleItem(
                        weekType: weekType,
                        dayOfWeek: dow,
                        lessonNumber: lessonNum,
                        groupName: transfer.group,
                        teacherName: transfer.substituteTeacher ?? transfer.teacher,
                        subjectName: transfer.subject,
                        lessonType: "П", // По умолчанию
                        room: transfer.newRoom ?? "",
                        source: "transfer",
                        isMovedIn: true,
                        transferNote: note
                    )
                    result.append(newItem)
                }
                
            case .roomChange:
                if let ad = transfer.additionDate, cal.startOfDay(for: ad) == targetDay {
                    for i in 0..<result.count {
                        if result[i].lessonNumber == transfer.additionLesson {
                            result[i].isRoomChanged = true
                            if let nr = transfer.newRoom {
                                result[i].room = nr
                                result[i].transferNote = "Замена аудитории на \(nr)"
                            }
                        }
                    }
                }
            }
        }
        
        return result.sorted { $0.lessonNumber < $1.lessonNumber }
    }
    
    // MARK: - Lesson Windows / Gaps
    public static func computeGaps(for lessons: [ScheduleItem], dayOfWeek: Int) -> [LessonGap] {
        let active = lessons
            .filter { !$0.isCancelled && !$0.isExcluded && !$0.isSkipped }
            .sorted { $0.lessonNumber < $1.lessonNumber }
        guard active.count >= 2 else { return [] }
        
        let bellTimes = Constants.getLessonTimes(dayOfWeek: dayOfWeek)
        var gaps: [LessonGap] = []
        
        for idx in 1..<active.count {
            let prev = active[idx - 1]
            let curr = active[idx]
            
            guard curr.lessonNumber - prev.lessonNumber >= 2,
                  prev.lessonNumber >= 1, prev.lessonNumber <= bellTimes.count,
                  curr.lessonNumber >= 1, curr.lessonNumber <= bellTimes.count else {
                continue
            }
            
            let prevEnd = bellTimes[prev.lessonNumber - 1].end
            let currStart = bellTimes[curr.lessonNumber - 1].start
            
            guard let prevEndMin = parseMinutes(prevEnd),
                  let currStartMin = parseMinutes(currStart) else {
                continue
            }
            
            let diff = currStartMin - prevEndMin
            guard diff > 0 else { continue }
            
            let hours = diff / 60
            let mins = diff % 60
            let formatted: String
            if hours > 0 && mins > 0 {
                formatted = "\(hours) ч \(mins) мин"
            } else if hours > 0 {
                formatted = "\(hours) ч"
            } else {
                formatted = "\(mins) мин"
            }
            
            gaps.append(
                LessonGap(
                    afterLessonNumber: prev.lessonNumber,
                    beforeLessonNumber: curr.lessonNumber,
                    startTime: prevEnd,
                    endTime: currStart,
                    durationMinutes: diff,
                    formattedDuration: formatted
                )
            )
        }
        
        return gaps
    }
    
    public static func buildDayScheduleEntries(for lessons: [ScheduleItem], dayOfWeek: Int) -> [DayScheduleEntry] {
        let sorted = lessons.sorted { $0.lessonNumber < $1.lessonNumber }
        let gaps = computeGaps(for: sorted, dayOfWeek: dayOfWeek)
        var gapsByBeforeLesson: [Int: LessonGap] = [:]
        for gap in gaps {
            if gapsByBeforeLesson[gap.beforeLessonNumber] == nil {
                gapsByBeforeLesson[gap.beforeLessonNumber] = gap
            }
        }
        
        var entries: [DayScheduleEntry] = []
        for item in sorted {
            if let gap = gapsByBeforeLesson.removeValue(forKey: item.lessonNumber) {
                entries.append(.gap(gap))
            }
            entries.append(.lesson(item))
        }
        return entries
    }
    
    private static func parseMinutes(_ timeStr: String) -> Int? {
        let parts = timeStr.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }
}
