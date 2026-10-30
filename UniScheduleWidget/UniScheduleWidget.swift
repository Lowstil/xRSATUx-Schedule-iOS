import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), targetName: "ИВБ-24", isDayOff: false, holidayName: nil, lessons: [
            WidgetLessonData(lessonNumber: 1, timeLabel: "08:30–10:05", subjectName: "Информационные технологии", room: "Г-417", lessonType: "Л", teacherOrGroup: "Иванов И.И.")
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = loadCurrentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entry = loadCurrentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadCurrentEntry() -> SimpleEntry {
        let defaults = UserDefaults(suiteName: "group.com.university.schedule") ?? UserDefaults.standard
        if let data = defaults.data(forKey: "today_widget_schedule"),
           let payload = try? JSONDecoder().decode(WidgetSchedulePayload.self, from: data) {
            return SimpleEntry(
                date: Date(),
                targetName: payload.targetName,
                isDayOff: payload.isDayOff,
                holidayName: payload.holidayName,
                lessons: payload.lessons
            )
        }
        return placeholder(in: nil as Any as! Context)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let targetName: String
    let isDayOff: Bool
    let holidayName: String?
    let lessons: [WidgetLessonData]
}

struct UniScheduleWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.targetName)
                    .font(.caption.bold())
                    .foregroundColor(.accentColor)
                Spacer()
                Text(Date(), style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if entry.isDayOff {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.orange)
                    Text(entry.holidayName ?? "Выходной")
                        .font(.caption.bold())
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else if entry.lessons.isEmpty {
                Spacer()
                Text("Пар нет 🎉")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.lessons.prefix(family == .systemSmall ? 2 : 3), id: \.lessonNumber) { lesson in
                    HStack(spacing: 6) {
                        Text("\(lesson.lessonNumber)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(lesson.subjectName)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Text("\(lesson.timeLabel) · \(lesson.room)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color(UIColor.systemBackground))
    }
}

@main
struct UniScheduleWidget: Widget {
    let kind: String = "UniScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            UniScheduleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Расписание РГАТУ")
        .description("Быстрый просмотр пар на сегодня прямо на экране «Домой».")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
