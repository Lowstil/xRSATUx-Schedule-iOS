import XCTest
@testable import UniSchedule

final class UniScheduleTests: XCTestCase {

    func testWeekCalculator() {
        let semesterStart = DateUtils.isoDateFormatter.date(from: "2026-09-01")!
        let calc = WeekCalculator(semesterStartDate: semesterStart)
        
        // 2026-09-01 is week 1 (odd)
        XCTAssertEqual(calc.getWeekNumber(for: semesterStart), 1)
        XCTAssertTrue(calc.isOddWeek(1))
        XCTAssertFalse(calc.isEvenWeek(1))
        
        // 14 days later is week 3
        let twoWeeksLater = Calendar.current.date(byAdding: .day, value: 14, to: semesterStart)!
        XCTAssertEqual(calc.getWeekNumber(for: twoWeeksLater), 3)
        XCTAssertEqual(calc.getWeekType(for: twoWeeksLater), Constants.weekTypeOdd)
        
        // 7 days later is week 2 (even)
        let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: semesterStart)!
        XCTAssertEqual(calc.getWeekNumber(for: oneWeekLater), 2)
        XCTAssertEqual(calc.getWeekType(for: oneWeekLater), Constants.weekTypeEven)
    }

    func testHolidayChecker() {
        let checker = HolidayChecker.shared
        
        // Jan 1 is holiday (New Year)
        let newYear = DateUtils.isoDateFormatter.date(from: "2026-01-01")!
        XCTAssertTrue(checker.isHoliday(date: newYear))
        XCTAssertTrue(checker.isDayOff(date: newYear))
        
        // May 9 is Victory Day
        let victoryDay = DateUtils.isoDateFormatter.date(from: "2026-05-09")!
        XCTAssertTrue(checker.isHoliday(date: victoryDay))
        
        // Sunday is weekend
        // 2026-11-01 is Sunday
        let sunday = DateUtils.isoDateFormatter.date(from: "2026-11-01")!
        XCTAssertTrue(checker.isWeekend(date: sunday))
        XCTAssertTrue(checker.isDayOff(date: sunday))
    }

    func testScheduleItemActiveWeek() {
        var item = ScheduleItem(
            weekType: "odd",
            dayOfWeek: 1,
            lessonNumber: 1,
            groupName: "ИВБ-24",
            teacherName: "Иванов И.И.",
            subjectName: "Физика",
            lessonType: "Л",
            room: "Г-100",
            weekSpec: "1-10,12"
        )
        
        XCTAssertTrue(item.isActiveOnWeek(1))
        XCTAssertTrue(item.isActiveOnWeek(5))
        XCTAssertTrue(item.isActiveOnWeek(10))
        XCTAssertFalse(item.isActiveOnWeek(11))
        XCTAssertTrue(item.isActiveOnWeek(12))
        XCTAssertFalse(item.isActiveOnWeek(13))
        
        // Empty weekSpec means active all weeks
        item.weekSpec = ""
        XCTAssertTrue(item.isActiveOnWeek(15))
    }

    func testScheduleClock() {
        // Test parsing lesson times
        let timesWeekday = Constants.getLessonTimes(dayOfWeek: 1)
        XCTAssertEqual(timesWeekday.count, 7)
        XCTAssertEqual(timesWeekday[0].start, "08:30")
        XCTAssertEqual(timesWeekday[0].end, "10:05")
        
        // Saturday has different bell schedule
        let timesSat = Constants.getLessonTimes(dayOfWeek: 6)
        XCTAssertEqual(timesSat[2].start, "12:00") // 12:00 instead of 12:40
    }

    func testAttendanceFormatSkips() {
        XCTAssertEqual(AttendanceManager.formatSkips(0), "0 Н-ок")
        XCTAssertEqual(AttendanceManager.formatSkips(1), "1 Н-ка")
        XCTAssertEqual(AttendanceManager.formatSkips(2), "2 Н-ки")
        XCTAssertEqual(AttendanceManager.formatSkips(3), "3 Н-ки")
        XCTAssertEqual(AttendanceManager.formatSkips(4), "4 Н-ки")
        XCTAssertEqual(AttendanceManager.formatSkips(5), "5 Н-ок")
        XCTAssertEqual(AttendanceManager.formatSkips(11), "11 Н-ок")
        XCTAssertEqual(AttendanceManager.formatSkips(12), "12 Н-ок")
        XCTAssertEqual(AttendanceManager.formatSkips(21), "21 Н-ка")
        XCTAssertEqual(AttendanceManager.formatSkips(22), "22 Н-ки")
        XCTAssertEqual(AttendanceManager.formatSkips(25), "25 Н-ок")
    }

    func testAttendanceStatusAndWarning() {
        let saNormal = AttendanceManager.SubjectAttendance(subjectName: "Математика", totalPlanned: 10, missedCount: 2, attendedCount: 8, attendancePercent: 80)
        XCTAssertFalse(saNormal.hasWarning)
        
        let saWarning = AttendanceManager.SubjectAttendance(subjectName: "Физика", totalPlanned: 10, missedCount: 3, attendedCount: 7, attendancePercent: 70)
        XCTAssertTrue(saWarning.hasWarning)
        
        let saManySkips = AttendanceManager.SubjectAttendance(subjectName: "Информатика", totalPlanned: 10, missedCount: 5, attendedCount: 5, attendancePercent: 50)
        XCTAssertTrue(saManySkips.hasWarning)
        
        var item = ScheduleItem(
            weekType: "odd",
            dayOfWeek: 1,
            lessonNumber: 1,
            groupName: "ИВБ-24",
            teacherName: "Иванов И.И.",
            subjectName: "Физика",
            lessonType: "Л",
            room: "Г-100"
        )
        XCTAssertEqual(item.attendanceStatus, .none)
        item.isAttended = true
        XCTAssertEqual(item.attendanceStatus, .attended)
        item.isAttended = false
        item.isSkipped = true
        XCTAssertEqual(item.attendanceStatus, .skipped)
    }

    // MARK: - 3.0 Tests

    func testInitialScheduleDate() {
        XCTAssertNil(DateUtils.initialScheduleDate(nil))

        // 2026-11-01 is Sunday -> should advance to Monday 2026-11-02
        let sunday = DateUtils.isoDateFormatter.date(from: "2026-11-01")!
        let monday = DateUtils.isoDateFormatter.date(from: "2026-11-02")!
        let resolvedSunday = DateUtils.initialScheduleDate(sunday)
        XCTAssertNotNil(resolvedSunday)
        XCTAssertEqual(
            DateUtils.isoDateFormatter.string(from: resolvedSunday!),
            DateUtils.isoDateFormatter.string(from: monday)
        )

        // Monday through Saturday stay on the same date
        let wednesday = DateUtils.isoDateFormatter.date(from: "2026-11-04")!
        XCTAssertEqual(DateUtils.initialScheduleDate(wednesday), wednesday)

        let saturday = DateUtils.isoDateFormatter.date(from: "2026-11-07")!
        XCTAssertEqual(DateUtils.initialScheduleDate(saturday), saturday)
    }

    func testScheduleFilterSortingGapsAndEntries() {
        let filter = ScheduleFilter(holidayChecker: .shared)
        let l3 = ScheduleItem(
            weekType: "odd", dayOfWeek: 1, lessonNumber: 3,
            groupName: "ИВБ-24", teacherName: "Иванов И.И.",
            subjectName: "Математика", lessonType: "Л", room: "1-201"
        )
        let l1 = ScheduleItem(
            weekType: "odd", dayOfWeek: 1, lessonNumber: 1,
            groupName: "ИВБ-24", teacherName: "Петров П.П.",
            subjectName: "Физика", lessonType: "П", room: "Г-105"
        )
        let l2Cancelled = ScheduleItem(
            weekType: "odd", dayOfWeek: 1, lessonNumber: 2,
            groupName: "ИВБ-24", teacherName: "Сидоров С.С.",
            subjectName: "Химия", lessonType: "ЛР", room: "2-301",
            isCancelled: true
        )
        let l4Excluded = ScheduleItem(
            weekType: "odd", dayOfWeek: 1, lessonNumber: 4,
            groupName: "ИВБ-24", teacherName: "Сидоров С.С.",
            subjectName: "История", lessonType: "П", room: "1-101",
            isExcluded: true
        )
        let l5Skipped = ScheduleItem(
            weekType: "odd", dayOfWeek: 1, lessonNumber: 5,
            groupName: "ИВБ-24", teacherName: "Сидоров С.С.",
            subjectName: "Английский", lessonType: "П", room: "1-102",
            isSkipped: true
        )
        let l6Active = ScheduleItem(
            weekType: "odd", dayOfWeek: 1, lessonNumber: 6,
            groupName: "ИВБ-24", teacherName: "Кузнецов К.К.",
            subjectName: "Программирование", lessonType: "ЛР", room: "Г-302"
        )

        // Ascending sort in filterLessonsForDay
        let sorted = filter.filterLessonsForDay(
            allItems: [l3, l1],
            dayOfWeek: 1,
            weekType: "odd",
            weekNumber: 1
        )
        XCTAssertEqual(sorted.map(\.lessonNumber), [1, 3])

        // Weekday gaps: between 1 (ends 10:05) and 3 (starts 12:40) -> 155 min ("2 ч 35 мин"), ignoring cancelled #2;
        // between 3 (ends 14:15) and 6 (starts 18:00) -> 225 min ("3 ч 45 мин"), ignoring excluded #4 and skipped #5.
        let weekdayGaps = ScheduleFilter.computeGaps(
            for: [l6Active, l2Cancelled, l3, l5Skipped, l1, l4Excluded],
            dayOfWeek: 1
        )
        XCTAssertEqual(weekdayGaps.count, 2)
        XCTAssertEqual(weekdayGaps[0].afterLessonNumber, 1)
        XCTAssertEqual(weekdayGaps[0].beforeLessonNumber, 3)
        XCTAssertEqual(weekdayGaps[0].startTime, "10:05")
        XCTAssertEqual(weekdayGaps[0].endTime, "12:40")
        XCTAssertEqual(weekdayGaps[0].durationMinutes, 155)
        XCTAssertEqual(weekdayGaps[0].formattedDuration, "2 ч 35 мин")

        XCTAssertEqual(weekdayGaps[1].afterLessonNumber, 3)
        XCTAssertEqual(weekdayGaps[1].beforeLessonNumber, 6)
        XCTAssertEqual(weekdayGaps[1].startTime, "14:15")
        XCTAssertEqual(weekdayGaps[1].endTime, "18:00")
        XCTAssertEqual(weekdayGaps[1].durationMinutes, 225)
        XCTAssertEqual(weekdayGaps[1].formattedDuration, "3 ч 45 мин")

        // Saturday uses weekend bell schedule (lesson 3 starts 12:00, not 12:40 -> 115 min = "1 ч 55 мин")
        let satGaps = ScheduleFilter.computeGaps(for: [l1, l3], dayOfWeek: 6)
        XCTAssertEqual(satGaps.count, 1)
        XCTAssertEqual(satGaps[0].startTime, "10:05")
        XCTAssertEqual(satGaps[0].endTime, "12:00")
        XCTAssertEqual(satGaps[0].durationMinutes, 115)
        XCTAssertEqual(satGaps[0].formattedDuration, "1 ч 55 мин")

        // buildDayScheduleEntries interleaves gaps right before target lessons
        let entries = ScheduleFilter.buildDayScheduleEntries(for: [l3, l1], dayOfWeek: 1)
        XCTAssertEqual(entries.count, 3)
        if case .lesson(let first) = entries[0] {
            XCTAssertEqual(first.lessonNumber, 1)
        } else {
            XCTFail("Expected lesson 1 first")
        }
        if case .gap(let gap) = entries[1] {
            XCTAssertEqual(gap.afterLessonNumber, 1)
            XCTAssertEqual(gap.beforeLessonNumber, 3)
        } else {
            XCTFail("Expected gap between 1 and 3")
        }
        if case .lesson(let second) = entries[2] {
            XCTAssertEqual(second.lessonNumber, 3)
        } else {
            XCTFail("Expected lesson 3 last")
        }
    }

    func testAttendance30BudgetAndFormatting() {
        XCTAssertEqual(AttendanceManager.formatLessonsCount(0), "0 пар")
        XCTAssertEqual(AttendanceManager.formatLessonsCount(1), "1 пара")
        XCTAssertEqual(AttendanceManager.formatLessonsCount(2), "2 пары")
        XCTAssertEqual(AttendanceManager.formatLessonsCount(4), "4 пары")
        XCTAssertEqual(AttendanceManager.formatLessonsCount(5), "5 пар")
        XCTAssertEqual(AttendanceManager.formatLessonsCount(11), "11 пар")
        XCTAssertEqual(AttendanceManager.formatLessonsCount(21), "21 пара")

        XCTAssertEqual(AttendanceManager.computeSkipPercent(missed: 0, planned: 0), 0)
        XCTAssertEqual(AttendanceManager.computeSkipPercent(missed: 3, planned: 10), 30)
        XCTAssertEqual(AttendanceManager.computeMaxAllowedSkips(planned: 10, limitPct: 30), 3)
        XCTAssertEqual(AttendanceManager.computeMaxAllowedSkips(planned: 10, limitPct: 25), 2)
        XCTAssertEqual(AttendanceManager.computeRemainingSkipBudget(missed: 1, planned: 10, limitPct: 30), 2)
        XCTAssertEqual(AttendanceManager.computeRemainingSkipBudget(missed: 4, planned: 10, limitPct: 30), -1)

        XCTAssertEqual(AttendanceManager.evaluateBudgetHealth(missed: 0, planned: 0, limitPct: 30), .safe)
        XCTAssertEqual(AttendanceManager.evaluateBudgetHealth(missed: 1, planned: 10, limitPct: 30), .safe)
        XCTAssertEqual(AttendanceManager.evaluateBudgetHealth(missed: 2, planned: 10, limitPct: 30), .warning)
        XCTAssertEqual(AttendanceManager.evaluateBudgetHealth(missed: 3, planned: 10, limitPct: 30), .warning)
        XCTAssertEqual(AttendanceManager.evaluateBudgetHealth(missed: 4, planned: 10, limitPct: 30), .exceeded)

        XCTAssertEqual(AttendanceManager.formatBudgetStatus(missed: 0, planned: 0, limitPct: 30), "Нет проведённых пар")
        XCTAssertEqual(AttendanceManager.formatBudgetStatus(missed: 0, planned: 3, limitPct: 20), "Пропусков нет · запас 0 пар")
        XCTAssertEqual(AttendanceManager.formatBudgetStatus(missed: 1, planned: 10, limitPct: 30), "Можно пропустить ещё 2 пары")
        XCTAssertEqual(AttendanceManager.formatBudgetStatus(missed: 2, planned: 10, limitPct: 30), "Последний запас: 1 пара")
        XCTAssertEqual(AttendanceManager.formatBudgetStatus(missed: 3, planned: 10, limitPct: 30), "Запас исчерпан (30%)")
        XCTAssertEqual(AttendanceManager.formatBudgetStatus(missed: 4, planned: 10, limitPct: 30), "Лимит превышен! (40%)")

        // skipLimitPercent validation with isolated UserDefaults suite
        let suiteName = "UniScheduleTests.Attendance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let manager = AttendanceManager(userDefaults: defaults)
        XCTAssertEqual(manager.skipLimitPercent, 30)
        manager.skipLimitPercent = 20
        XCTAssertEqual(manager.skipLimitPercent, 20)
        manager.skipLimitPercent = 25
        XCTAssertEqual(manager.skipLimitPercent, 25)
        manager.skipLimitPercent = 99
        XCTAssertEqual(manager.skipLimitPercent, 30)
    }

    func testScheduleDiffComputer() {
        let base1 = ScheduleItem(
            weekType: "odd", dayOfWeek: 1, lessonNumber: 1,
            groupName: "ИВБ-24", teacherName: "Иванов И.И.",
            subjectName: "Физика", lessonType: "Л", room: "Г-100"
        )
        let base2 = ScheduleItem(
            weekType: "odd", dayOfWeek: 2, lessonNumber: 2,
            groupName: "ИВБ-24", teacherName: "Петров П.П.",
            subjectName: "Математика", lessonType: "П", room: "1-201"
        )
        let base3 = ScheduleItem(
            weekType: "even", dayOfWeek: 3, lessonNumber: 1,
            groupName: "ИВБ-24", teacherName: "Сидоров С.С.",
            subjectName: "Химия", lessonType: "ЛР", room: "2-105"
        )

        // Identical lists produce empty diff
        let emptyDiff = ScheduleDiffComputer.computeDiff(
            oldItems: [base1, base2],
            newItems: [base2, base1],
            targetName: "ИВБ-24",
            isGroup: true
        )
        XCTAssertTrue(emptyDiff.isEmpty)

        // Room changed, teacher changed, removed, and added
        var base1RoomChanged = base1
        base1RoomChanged.room = "Г-205"
        var base2TeacherChanged = base2
        base2TeacherChanged.teacherName = "Смирнов А.А."
        let addedItem = ScheduleItem(
            weekType: "odd", dayOfWeek: 4, lessonNumber: 3,
            groupName: "ИВБ-24", teacherName: "Кузнецов К.К.",
            subjectName: "Информатика", lessonType: "ЛР", room: "Г-302"
        )

        let diff = ScheduleDiffComputer.computeDiff(
            oldItems: [base1, base2, base3],
            newItems: [base1RoomChanged, base2TeacherChanged, addedItem],
            targetName: "ИВБ-24",
            isGroup: true
        )
        XCTAssertFalse(diff.isEmpty)
        XCTAssertEqual(diff.changes.count, 4)

        let kinds = Set(diff.changes.map(\.kind))
        XCTAssertTrue(kinds.contains(.roomChanged))
        XCTAssertTrue(kinds.contains(.teacherChanged))
        XCTAssertTrue(kinds.contains(.removed))
        XCTAssertTrue(kinds.contains(.added))

        let roomChange = diff.changes.first { $0.kind == .roomChanged }
        XCTAssertEqual(roomChange?.oldValue, "Г-100")
        XCTAssertEqual(roomChange?.newValue, "Г-205")

        let teacherChange = diff.changes.first { $0.kind == .teacherChanged }
        XCTAssertEqual(teacherChange?.oldValue, "Петров П.П.")
        XCTAssertEqual(teacherChange?.newValue, "Смирнов А.А.")
    }

    func testScheduleExporterFormatDayAsText() {
        let monday = DateUtils.isoDateFormatter.date(from: "2026-11-02")!
        let activeLesson = ScheduleItem(
            weekType: "odd", dayOfWeek: 1, lessonNumber: 1,
            groupName: "ИВБ-24", teacherName: "Иванов И.И.",
            subjectName: "Физика", lessonType: "Л", room: "Г-100"
        )
        let cancelledLesson = ScheduleItem(
            weekType: "odd", dayOfWeek: 1, lessonNumber: 2,
            groupName: "ИВБ-24", teacherName: "Петров П.П.",
            subjectName: "Отменённый предмет", lessonType: "П", room: "1-202",
            isCancelled: true
        )
        let day = DaySchedule(
            dayOfWeek: 1,
            date: monday,
            lessons: [cancelledLesson, activeLesson],
            isDayOff: false
        )

        let exported = ScheduleExporter.formatDayAsText(day: day, targetName: "ИВБ-24", isGroup: true)
        XCTAssertTrue(exported.contains("Расписание · ИВБ-24"))
        XCTAssertTrue(exported.contains("Понедельник, 02.11.2026"))
        XCTAssertTrue(exported.contains("1 пара"))
        XCTAssertTrue(exported.contains("Физика"))
        XCTAssertTrue(exported.contains("ауд. Г-100"))
        XCTAssertTrue(exported.contains("Иванов И.И."))
        XCTAssertFalse(exported.contains("Отменённый предмет"))
    }
}
