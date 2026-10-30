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
}
