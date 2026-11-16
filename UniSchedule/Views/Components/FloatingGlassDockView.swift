import SwiftUI

// MARK: - Floating Liquid Glass Bottom Dock

public struct FloatingGlassDockView: View {
    public let pendingNotesCount: Int
    public let onPairsTap: () -> Void
    public let onAttendanceTap: () -> Void
    public let onRoomsTap: () -> Void
    public let onMoreTap: () -> Void

    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    public init(
        pendingNotesCount: Int,
        onPairsTap: @escaping () -> Void,
        onAttendanceTap: @escaping () -> Void,
        onRoomsTap: @escaping () -> Void,
        onMoreTap: @escaping () -> Void
    ) {
        self.pendingNotesCount = pendingNotesCount
        self.onPairsTap = onPairsTap
        self.onAttendanceTap = onAttendanceTap
        self.onRoomsTap = onRoomsTap
        self.onMoreTap = onMoreTap
    }

    private var effectiveReduced: Bool {
        reducedTransparency || systemReduceTransparency
    }

    private var pendingBadgeText: String? {
        guard pendingNotesCount > 0 else { return nil }
        return pendingNotesCount > 99 ? "99+" : "\(pendingNotesCount)"
    }

    public var body: some View {
        HStack(spacing: 4) {
            dockButton(
                title: "Пары",
                systemImage: "calendar",
                isActive: true,
                badge: nil
            ) {
                HapticsService.shared.selection()
                onPairsTap()
            }

            dockButton(
                title: "Н-ки",
                systemImage: "checkmark.circle",
                isActive: false,
                badge: nil
            ) {
                HapticsService.shared.impact(.light)
                onAttendanceTap()
            }

            dockButton(
                title: "Аудитории",
                systemImage: "building.2",
                isActive: false,
                badge: nil
            ) {
                HapticsService.shared.impact(.light)
                onRoomsTap()
            }

            dockButton(
                title: "Ещё",
                systemImage: "ellipsis",
                isActive: false,
                badge: pendingBadgeText
            ) {
                HapticsService.shared.impact(.light)
                onMoreTap()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            ZStack {
                if effectiveReduced {
                    Capsule().fill(Color.uniGlassSurfaceFallback)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().fill(Color.uniGlassSurfaceStrong)
                }
            }
        )
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(
                LinearGradient(
                    colors: [Color.uniGlassStrokeStart, Color.uniGlassStrokeMid, Color.uniGlassStrokeEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.1
            )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.42 : 0.14),
            radius: 16,
            x: 0,
            y: 8
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func dockButton(
        title: String,
        systemImage: String,
        isActive: Bool,
        badge: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: isActive ? .bold : .semibold))
                        .frame(height: 20)

                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .heavy).monospacedDigit())
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.accentColor))
                            .offset(x: 13, y: -5)
                    }
                }

                Text(title)
                    .font(.system(size: 11, weight: isActive ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundColor(isActive ? .accentColor : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                Group {
                    if isActive {
                        Capsule()
                            .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 0.8)
                            )
                    }
                }
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - More Actions Sheet ("Ещё")

public struct MoreActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false

    public let pendingNotesCount: Int
    public let isUpdating: Bool
    public let hasScheduleDiff: Bool
    public let onCustomEvent: () -> Void
    public let onCompareGroups: () -> Void
    public let onHomeworkHub: () -> Void
    public let onBellSchedule: () -> Void
    public let onScheduleDiff: () -> Void
    public let onExportSchedule: () -> Void
    public let onRefreshSchedule: () -> Void
    public let onSettings: () -> Void

    public init(
        pendingNotesCount: Int,
        isUpdating: Bool = false,
        hasScheduleDiff: Bool = false,
        onCustomEvent: @escaping () -> Void,
        onCompareGroups: @escaping () -> Void,
        onHomeworkHub: @escaping () -> Void,
        onBellSchedule: @escaping () -> Void,
        onScheduleDiff: @escaping () -> Void,
        onExportSchedule: @escaping () -> Void,
        onRefreshSchedule: @escaping () -> Void,
        onSettings: @escaping () -> Void
    ) {
        self.pendingNotesCount = pendingNotesCount
        self.isUpdating = isUpdating
        self.hasScheduleDiff = hasScheduleDiff
        self.onCustomEvent = onCustomEvent
        self.onCompareGroups = onCompareGroups
        self.onHomeworkHub = onHomeworkHub
        self.onBellSchedule = onBellSchedule
        self.onScheduleDiff = onScheduleDiff
        self.onExportSchedule = onExportSchedule
        self.onRefreshSchedule = onRefreshSchedule
        self.onSettings = onSettings
    }

    private var pendingBadgeText: String? {
        guard pendingNotesCount > 0 else { return nil }
        return pendingNotesCount > 99 ? "99+" : "\(pendingNotesCount)"
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(reducedTransparency: reducedTransparency)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        actionRow(
                            icon: "plus.circle.fill",
                            iconColor: .uniCustomPurple,
                            title: "Личное событие",
                            subtitle: "Добавить пару, встречу или дедлайн"
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onCustomEvent()
                        }

                        actionRow(
                            icon: "arrow.left.arrow.right.circle.fill",
                            iconColor: .uniNextSky,
                            title: "Сравнить группы (Общие окна)",
                            subtitle: "Найти свободные пары двух групп"
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onCompareGroups()
                        }

                        actionRow(
                            icon: "note.text",
                            iconColor: .uniLiveEmerald,
                            title: "Домашки и заметки",
                            subtitle: "Задания, фото и быстрый переход к паре",
                            badge: pendingBadgeText
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onHomeworkHub()
                        }

                        actionRow(
                            icon: "bell.badge.fill",
                            iconColor: .uniWindowAmber,
                            title: "Расписание звонков",
                            subtitle: "Будни и суббота"
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onBellSchedule()
                        }

                        actionRow(
                            icon: "arrow.triangle.2.circlepath",
                            iconColor: hasScheduleDiff ? .uniNextSky : .secondary,
                            title: "Что изменилось",
                            subtitle: hasScheduleDiff ? "Есть изменения после обновления" : "Просмотреть журнал изменений"
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onScheduleDiff()
                        }

                        actionRow(
                            icon: "square.and.arrow.up",
                            iconColor: .accentColor,
                            title: "Экспорт расписания",
                            subtitle: "Текст или карточка Liquid Glass"
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onExportSchedule()
                        }

                        actionRow(
                            icon: "arrow.clockwise",
                            iconColor: .uniLiveEmerald,
                            title: "Обновить расписание",
                            subtitle: isUpdating ? "Идёт загрузка..." : "Загрузить свежий файл с сайта",
                            isLoading: isUpdating
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onRefreshSchedule()
                        }

                        actionRow(
                            icon: "gearshape.fill",
                            iconColor: .secondary,
                            title: "Настройки",
                            subtitle: "Семестр, тема, уведомления и о приложении"
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onSettings()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Ещё")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func actionRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        badge: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.opacity(0.16))
                        .frame(width: 38, height: 38)

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                if let badge {
                    Text(badge)
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentColor))
                }

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .liquidGlassCard(cornerRadius: 16, state: .normal, reducedTransparency: reducedTransparency)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Top Semester Toast Pill

public struct SemesterToastPill: View {
    public let message: String?

    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false
    @Environment(\.colorScheme) private var colorScheme

    public init(message: String?) {
        self.message = message
    }

    public var body: some View {
        Group {
            if let message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.accentColor)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .liquidGlassCapsule(tint: .accentColor, reducedTransparency: reducedTransparency)
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12),
                        radius: 10,
                        x: 0,
                        y: 4
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: message)
        .allowsHitTesting(false)
    }
}
