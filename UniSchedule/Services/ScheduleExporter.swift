import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum ExportMode: String, CaseIterable, Identifiable {
    case todayText = "Сегодня — текст"
    case todayImage = "Сегодня — картинка (Liquid Glass)"
    case weekText = "Текущая неделя — текст"
    case weekImage = "Текущая неделя — картинка (Liquid Glass)"

    public var id: String { rawValue }

    public var isImage: Bool {
        switch self {
        case .todayImage, .weekImage: return true
        case .todayText, .weekText: return false
        }
    }

    public var isWeek: Bool {
        switch self {
        case .weekText, .weekImage: return true
        case .todayText, .todayImage: return false
        }
    }

    public var systemImage: String {
        switch self {
        case .todayText: return "doc.plaintext"
        case .todayImage: return "photo.artframe"
        case .weekText: return "calendar.badge.clock"
        case .weekImage: return "sparkles.rectangle.stack"
        }
    }

    public var subtitle: String {
        switch self {
        case .todayText: return "Удобно вставить в мессенджер или заметки"
        case .todayImage: return "Тёмная карточка Liquid Glass (PNG)"
        case .weekText: return "Все учебные дни текущей недели списком"
        case .weekImage: return "Полная неделя на одной карточке (PNG)"
        }
    }
}

public enum ScheduleExporter {
    // MARK: - Text Formatters

    public static func formatDayAsText(
        day: DaySchedule,
        targetName: String,
        isGroup: Bool
    ) -> String {
        var lines: [String] = []
        let dateStr = DateUtils.formatDisplayDate(day.date)
        lines.append("📅 Расписание · \(targetName)")
        lines.append("📆 \(day.dayNameFull), \(dateStr)")
        lines.append("")

        if day.isDayOff {
            if let holiday = day.holidayName, !holiday.isEmpty {
                lines.append("🎉 \(holiday) — выходной день")
            } else {
                lines.append("🌴 Выходной день")
            }
            return lines.joined(separator: "\n")
        }

        let activeLessons = day.lessons
            .filter { !$0.isCancelled }
            .sorted { $0.lessonNumber < $1.lessonNumber }

        if activeLessons.isEmpty {
            lines.append("Занятий нет ✨")
            return lines.joined(separator: "\n")
        }

        for lesson in activeLessons {
            lines.append(formatLessonLine(lesson, dayOfWeek: day.dayOfWeek, isGroup: isGroup))
        }

        return lines.joined(separator: "\n")
    }

    public static func formatWeekAsText(
        week: WeekSchedule,
        targetName: String,
        isGroup: Bool
    ) -> String {
        var lines: [String] = []
        lines.append("📅 Расписание · \(targetName)")
        lines.append("📆 \(week.weekDescription)")

        for day in week.days {
            lines.append("")
            let dateShort = DateUtils.formatDisplayDateShort(day.date)
            lines.append("— \(day.dayNameFull) (\(dateShort)) —")

            if day.isDayOff {
                if let holiday = day.holidayName, !holiday.isEmpty {
                    lines.append("  🎉 \(holiday)")
                } else {
                    lines.append("  🌴 Выходной день")
                }
                continue
            }

            let activeLessons = day.lessons
                .filter { !$0.isCancelled }
                .sorted { $0.lessonNumber < $1.lessonNumber }

            if activeLessons.isEmpty {
                lines.append("  Занятий нет")
                continue
            }

            for lesson in activeLessons {
                lines.append(formatLessonLine(lesson, dayOfWeek: day.dayOfWeek, isGroup: isGroup))
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func formatLessonLine(
        _ lesson: ScheduleItem,
        dayOfWeek: Int,
        isGroup: Bool
    ) -> String {
        let timeLabel = Constants.getLessonTimeLabel(dayOfWeek: dayOfWeek, lessonNumber: lesson.lessonNumber)
        let timePart = timeLabel.isEmpty ? "" : " · ⏰ \(timeLabel)"
        let typePart = lesson.lessonType.isEmpty ? "" : " [\(lesson.lessonType)]"
        var result = "\(lesson.lessonNumber) пара\(timePart) — \(lesson.subjectName)\(typePart)"

        var meta: [String] = []
        if lesson.isOnline {
            meta.append(lesson.room.isEmpty ? "💻 Онлайн" : "💻 Онлайн (\(lesson.room))")
        } else if !lesson.room.isEmpty {
            meta.append("🏫 ауд. \(lesson.room)")
        }

        let peer = isGroup ? lesson.teacherName : lesson.groupName
        if !peer.isEmpty {
            meta.append(isGroup ? "👤 \(peer)" : "👥 \(peer)")
        }

        if !meta.isEmpty {
            result += "\n   " + meta.joined(separator: " · ")
        }
        return result
    }

    // MARK: - Liquid Glass PNG Renderer (iOS 17 ImageRenderer)

    @MainActor
    public static func renderDayImage(
        day: DaySchedule,
        targetName: String,
        isGroup: Bool
    ) -> URL? {
        let subtitle = "\(day.dayNameFull), \(DateUtils.formatDisplayDate(day.date))"
        let content = ExportGlassCardView(
            title: "Расписание · \(targetName)",
            subtitle: subtitle,
            days: [day],
            isGroup: isGroup
        )
        return renderPNG(view: content, fileName: "schedule_day.png")
    }

    @MainActor
    public static func renderWeekImage(
        week: WeekSchedule,
        targetName: String,
        isGroup: Bool
    ) -> URL? {
        let content = ExportGlassCardView(
            title: "Расписание · \(targetName)",
            subtitle: week.weekDescription,
            days: week.days,
            isGroup: isGroup
        )
        return renderPNG(view: content, fileName: "schedule_week.png")
    }

    @MainActor
    private static func renderPNG<V: View>(view: V, fileName: String) -> URL? {
        #if canImport(UIKit)
        let renderer = ImageRenderer(content: view.frame(width: 540))
        renderer.scale = 2.0 // 540pt @ 2x = 1080px wide
        guard let image = renderer.uiImage,
              let pngData = image.pngData() else {
            return nil
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pngData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    fileprivate static func pillColor(for lessonType: String) -> Color {
        switch lessonType.trimmingCharacters(in: .whitespacesAndNewlines) {
        case Constants.lessonTypeLecture, Constants.lessonTypeOnlineLecture:
            return .typeLecture
        case Constants.lessonTypePractice, Constants.lessonTypeOnlinePractice:
            return .typePractice
        case Constants.lessonTypeLab:
            return .typeLab
        case Constants.lessonTypeExam:
            return .typeExam
        default:
            return lessonType.hasPrefix("о") ? .typeOnline : .typeLecture
        }
    }
}

// MARK: - Offscreen Liquid Glass Export Card

private struct ExportGlassCardView: View {
    let title: String
    let subtitle: String
    let days: [DaySchedule]
    let isGroup: Bool

    var body: some View {
        ZStack {
            // Deep Liquid Glass backdrop
            LinearGradient(
                colors: [
                    Color(hex: "090D1A"),
                    Color(hex: "0F172A"),
                    Color(hex: "131C36")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Ambient blobs
            Circle()
                .fill(Color(hex: "3B82F6").opacity(0.28))
                .frame(width: 340, height: 340)
                .blur(radius: 75)
                .offset(x: -140, y: -160)

            Circle()
                .fill(Color(hex: "10B981").opacity(0.20))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 160, y: 150)

            Circle()
                .fill(Color(hex: "8B5CF6").opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 75)
                .offset(x: 120, y: -120)

            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.72))
                }
                .padding(.bottom, 4)

                // Days
                ForEach(days) { day in
                    ExportDayBlockView(
                        day: day,
                        showDayHeader: days.count > 1,
                        isGroup: isGroup
                    )
                }

                // Footer
                HStack {
                    Spacer()
                    Text("xRSATUx Schedule · Liquid Glass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.42))
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
        .environment(\.colorScheme, .dark)
    }
}

private struct ExportDayBlockView: View {
    let day: DaySchedule
    let showDayHeader: Bool
    let isGroup: Bool

    private var activeLessons: [ScheduleItem] {
        day.lessons
            .filter { !$0.isCancelled }
            .sorted { $0.lessonNumber < $1.lessonNumber }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showDayHeader {
                HStack {
                    Text(day.dayNameFull)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    Text(DateUtils.formatDisplayDateShort(day.date))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.6))

                    Spacer()
                }
                .padding(.top, 4)
            }

            if day.isDayOff {
                exportGlassRow {
                    HStack(spacing: 10) {
                        Text("🌴")
                            .font(.system(size: 18))
                        Text(day.holidayName ?? "Выходной день")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.85))
                        Spacer()
                    }
                }
            } else if activeLessons.isEmpty {
                exportGlassRow {
                    HStack(spacing: 10) {
                        Text("✨")
                            .font(.system(size: 16))
                        Text("Занятий нет")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.65))
                        Spacer()
                    }
                }
            } else {
                ForEach(activeLessons) { lesson in
                    ExportLessonRowView(
                        lesson: lesson,
                        dayOfWeek: day.dayOfWeek,
                        isGroup: isGroup
                    )
                }
            }
        }
    }

    private func exportGlassRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.30),
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

private struct ExportLessonRowView: View {
    let lesson: ScheduleItem
    let dayOfWeek: Int
    let isGroup: Bool

    var body: some View {
        let pillColor = ScheduleExporter.pillColor(for: lesson.lessonType)
        let timeLabel = Constants.getLessonTimeLabel(dayOfWeek: dayOfWeek, lessonNumber: lesson.lessonNumber)
        let peer = isGroup ? lesson.teacherName : lesson.groupName

        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(pillColor)
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(lesson.lessonNumber) пара")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.9))

                    if !timeLabel.isEmpty {
                        Text(timeLabel)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.62))
                    }

                    Spacer()

                    if !lesson.lessonType.isEmpty {
                        Text(lesson.lessonType)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(pillColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(pillColor.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }

                Text(lesson.subjectName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    if lesson.isOnline {
                        Label(
                            lesson.room.isEmpty ? "Онлайн" : "Онлайн · \(lesson.room)",
                            systemImage: "wifi"
                        )
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.teal)
                    } else if !lesson.room.isEmpty {
                        Label("ауд. \(lesson.room)", systemImage: "door.left.hand.open")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.75))
                    }

                    if !peer.isEmpty {
                        Label(peer, systemImage: isGroup ? "person" : "person.2")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.32),
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - UIKit Share Sheet Wrapper

#if canImport(UIKit)
public struct ShareSheet: UIViewControllerRepresentable {
    public let items: [Any]

    public init(items: [Any]) {
        self.items = items
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
