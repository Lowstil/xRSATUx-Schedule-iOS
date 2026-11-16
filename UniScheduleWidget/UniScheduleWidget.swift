import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        makePlaceholderEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(loadCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = loadCurrentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func makePlaceholderEntry() -> SimpleEntry {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return SimpleEntry(
            date: Date(),
            targetName: "ИВБ-24",
            dateString: formatter.string(from: Date()),
            isDayOff: false,
            holidayName: nil,
            lessons: [
                WidgetLessonData(
                    lessonNumber: 1,
                    timeLabel: "08:30–10:05",
                    subjectName: "Информационные технологии",
                    room: "Г-417",
                    lessonType: "Л",
                    teacherOrGroup: "Иванов И.И."
                )
            ],
            isPreview: false,
            previewLabel: nil,
            semesterId: "fall"
        )
    }

    private func loadCurrentEntry() -> SimpleEntry {
        let defaults = UserDefaults(suiteName: "group.com.university.schedule") ?? UserDefaults.standard
        if let data = defaults.data(forKey: "today_widget_schedule"),
           let payload = try? JSONDecoder().decode(WidgetSchedulePayload.self, from: data) {
            return SimpleEntry(
                date: Date(),
                targetName: payload.targetName,
                dateString: payload.dateString,
                isDayOff: payload.isDayOff,
                holidayName: payload.holidayName,
                lessons: payload.lessons,
                isPreview: payload.isPreview,
                previewLabel: payload.previewLabel,
                semesterId: payload.semesterId
            )
        }
        return makePlaceholderEntry()
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let targetName: String
    let dateString: String
    let isDayOff: Bool
    let holidayName: String?
    let lessons: [WidgetLessonData]
    let isPreview: Bool
    let previewLabel: String?
    let semesterId: String
}

struct UniScheduleWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(entry.targetName)
                    .font(.caption.bold())
                    .foregroundColor(.accentColor)
                    .lineLimit(1)

                Spacer()

                if entry.isPreview, let badge = entry.previewLabel, !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.14))
                        .clipShape(Capsule())
                } else {
                    Text(Date(), style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            Spacer(minLength: 0)
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
