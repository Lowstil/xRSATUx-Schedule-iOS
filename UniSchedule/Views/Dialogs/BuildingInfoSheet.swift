import SwiftUI

public struct BuildingInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency: Bool = false

    public let rawRoom: String
    public let onOpenFreeRooms: (String?) -> Void

    public init(rawRoom: String, onOpenFreeRooms: @escaping (String?) -> Void) {
        self.rawRoom = rawRoom
        self.onOpenFreeRooms = onOpenFreeRooms
    }

    public var body: some View {
        let meta = RoomFormatter.resolveBuildingMeta(from: rawRoom)
        let parsedRoom = RoomFormatter.parse(rawRoom)
        let pillLabel = parsedRoom.isEmpty ? rawRoom : parsedRoom

        return NavigationStack {
            ZStack {
                AmbientBackdropView(reducedTransparency: reducedTransparency)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.uniNextSky.opacity(0.18))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: meta.hasPhysicalRooms ? "building.2.fill" : "mappin.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.uniNextSky)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(meta.title)
                                        .font(.title3.bold())
                                        .foregroundColor(.primary)

                                    if !pillLabel.isEmpty {
                                        Text(pillLabel)
                                            .font(.caption.bold())
                                            .foregroundColor(.uniNextSky)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .liquidGlassCapsule(tint: .uniNextSky, reducedTransparency: reducedTransparency)
                                    }
                                }
                                Spacer(minLength: 0)
                            }

                            Divider().opacity(0.4)

                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.subheadline)
                                    .foregroundColor(.uniLiveEmerald)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Адрес")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                    Text(meta.address)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            }

                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "figure.walk")
                                    .font(.subheadline)
                                    .foregroundColor(.uniWindowAmber)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Переходы между корпусами")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                    Text(meta.walkHint)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(18)
                        .liquidGlassCard(cornerRadius: 20, reducedTransparency: reducedTransparency)

                        if meta.hasPhysicalRooms {
                            Button {
                                HapticsService.shared.selection()
                                let filter = meta.buildingFilter
                                dismiss()
                                onOpenFreeRooms(filter)
                            } label: {
                                HStack(spacing: 8) {
                                    Spacer()
                                    Image(systemName: "door.left.hand.open")
                                    Text("Свободные аудитории")
                                        .font(.headline)
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.accentColor)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Информация о корпусе")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}
