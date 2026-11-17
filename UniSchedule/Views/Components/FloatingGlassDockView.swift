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
        .padding(.vertical, 5)
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
            color: Color.black.opacity(colorScheme == .dark ? 0.36 : 0.12),
            radius: 14,
            x: 0,
            y: 6
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
            VStack(spacing: 2.5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: isActive ? .bold : .semibold))
                        .frame(height: 19)

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
            .padding(.vertical, 6)
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
    public let onExportSchedule: (() -> Void)?
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
        onExportSchedule: (() -> Void)? = nil,
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
                    VStack(spacing: 8) {
                        actionRow(
                            emoji: "➕",
                            iconColor: .uniCustomPurple,
                            title: "Личное событие"
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onCustomEvent()
                        }

                        actionRow(
                            emoji: "⚖️",
                            iconColor: .uniNextSky,
                            title: "Сравнить группы (Общие окна)"
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onCompareGroups()
                        }

                        actionRow(
                            emoji: "📝",
                            iconColor: .uniLiveEmerald,
                            title: "Домашки и заметки",
                            badge: pendingBadgeText
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onHomeworkHub()
                        }

                        actionRow(
                            emoji: "🔔",
                            iconColor: .uniWindowAmber,
                            title: "Расписание звонков"
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onBellSchedule()
                        }

                        actionRow(
                            emoji: "🔄",
                            iconColor: hasScheduleDiff ? .uniNextSky : .secondary,
                            title: "Что изменилось"
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onScheduleDiff()
                        }

                        actionRow(
                            emoji: "↻",
                            iconColor: .uniLiveEmerald,
                            title: isUpdating ? "Обновление расписания..." : "Обновить расписание",
                            isLoading: isUpdating
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onRefreshSchedule()
                        }

                        actionRow(
                            emoji: "⚙",
                            iconColor: .secondary,
                            title: "Настройки"
                        ) {
                            HapticsService.shared.selection()
                            dismiss()
                            onSettings()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle("Ещё")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func actionRow(
        emoji: String,
        iconColor: Color,
        title: String,
        badge: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 34, height: 34)

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.78)
                    } else {
                        Text(emoji)
                            .font(.system(size: 16))
                    }
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer(minLength: 6)

                if let badge {
                    Text(badge)
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(Color.accentColor))
                }

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary.opacity(0.65))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidGlassCard(cornerRadius: 15, state: .normal, reducedTransparency: reducedTransparency)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Top Semester Toast Pill

public struct SemesterToastPill: View {
    public let message: String?

    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency = false
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    public init(message: String?) {
        self.message = message
    }

    private var effectiveReduced: Bool {
        reducedTransparency || systemReduceTransparency
    }

    public var body: some View {
        Group {
            if let message, !message.isEmpty {
                let shape = Capsule()
                Text(message)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.accentColor)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        ZStack {
                            if effectiveReduced {
                                shape.fill(Color.uniGlassSurfaceFallback)
                            } else {
                                shape.fill(.ultraThinMaterial)
                                shape.fill(Color.accentColor.opacity(0.14))
                            }
                        }
                    )
                    .clipShape(shape)
                    .overlay(
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.55), Color.accentColor.opacity(0.20)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    )
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
