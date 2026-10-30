import Foundation

public final class ScheduleClock {
    private init() {}
    
    public static func compute(
        for date: Date = Date(),
        scheduleLessons: [ScheduleItem] = []
    ) -> ScheduleClockState {
        let dow = DateUtils.toScheduleDayOfWeek(date: date)
        guard dow >= 1 && dow <= 6 else {
            return ScheduleClockState()
        }
        
        let times = Constants.getLessonTimes(dayOfWeek: dow)
        let cal = Calendar.current
        let nowComponents = cal.dateComponents([.hour, .minute], from: date)
        let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
        
        // Find existing lessons for today to know if lesson actually exists
        let activeLessons = scheduleLessons.filter { !$0.isCancelled && !$0.isExcluded && !$0.isSkipped }
        let lessonNumbers = Set(activeLessons.map { $0.lessonNumber })
        
        var currentLessonNumber: Int? = nil
        var nextLessonNumber: Int? = nil
        var minutesLeftInCurrent = -1
        var currentProgressPercent: Double = 0.0
        var minutesUntilNext = -1
        var isBreak = false
        var currentStage = 1
        var stageStatusText = ""
        
        for (index, timePair) in times.enumerated() {
            let lessonNum = index + 1
            let startMin = parseMinutes(timePair.start)
            let endMin = parseMinutes(timePair.end)
            
            // Check if within lesson
            if nowMinutes >= startMin && nowMinutes < endMin {
                currentLessonNumber = lessonNum
                let duration = endMin - startMin
                let elapsed = nowMinutes - startMin
                minutesLeftInCurrent = endMin - nowMinutes
                currentProgressPercent = duration > 0 ? Double(elapsed) / Double(duration) : 0.0
                
                // 3-stage breakdown for typical 95 min pair (45m lesson, 5m break, 45m lesson)
                if duration == 95 {
                    if elapsed < 45 {
                        currentStage = 1
                        stageStatusText = "1-я половина"
                    } else if elapsed < 50 {
                        currentStage = 2
                        stageStatusText = "Перерыв в паре (5 мин)"
                    } else {
                        currentStage = 3
                        stageStatusText = "2-я половина"
                    }
                }
                break
            }
            
            // Check if before this lesson and was after previous
            if nowMinutes < startMin {
                nextLessonNumber = lessonNum
                minutesUntilNext = startMin - nowMinutes
                
                if index > 0 {
                    let prevEndMin = parseMinutes(times[index - 1].end)
                    if nowMinutes >= prevEndMin {
                        isBreak = true
                    }
                } else {
                    isBreak = false
                }
                break
            }
        }
        
        // If current lesson isn't in student's schedule, clear current
        if let curr = currentLessonNumber, !lessonNumbers.isEmpty && !lessonNumbers.contains(curr) {
            currentLessonNumber = nil
        }
        
        // Find next valid scheduled lesson
        if let next = nextLessonNumber, !lessonNumbers.isEmpty && !lessonNumbers.contains(next) {
            // Find earliest scheduled lesson after now
            let future = lessonNumbers.filter { $0 >= next }.sorted()
            if let firstFuture = future.first, firstFuture <= times.count {
                nextLessonNumber = firstFuture
                let startMin = parseMinutes(times[firstFuture - 1].start)
                minutesUntilNext = max(0, startMin - nowMinutes)
            } else {
                nextLessonNumber = nil
                minutesUntilNext = -1
            }
        }
        
        return ScheduleClockState(
            currentLessonNumber: currentLessonNumber,
            nextLessonNumber: nextLessonNumber,
            minutesLeftInCurrent: minutesLeftInCurrent,
            currentProgressPercent: currentProgressPercent,
            minutesUntilNext: minutesUntilNext,
            isBreak: isBreak,
            currentStage: currentStage,
            stageStatusText: stageStatusText
        )
    }
    
    private static func parseMinutes(_ timeStr: String) -> Int {
        let parts = timeStr.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return 0 }
        return h * 60 + m
    }
}
