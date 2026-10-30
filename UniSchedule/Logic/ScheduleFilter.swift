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
        }
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
        
        return result
    }
}
