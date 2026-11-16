import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct HomeworkHubSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.prefReducedTransparency) private var reducedTransparency: Bool = false
    @ObservedObject private var repository = ScheduleRepository.shared

    public let onNavigateToDate: (Date) -> Void

    @State private var selectedFilter: Int = 0 // 0 = Активные, 1 = Все, 2 = Выполнено
    @State private var fullscreenPhoto: FullscreenPhotoItem? = nil

    public init(onNavigateToDate: @escaping (Date) -> Void) {
        self.onNavigateToDate = onNavigateToDate
    }

    private var allNotes: [LessonNote] {
        repository.getAllNotes()
    }

    private var pendingCount: Int {
        allNotes.filter { !$0.isCompleted }.count
    }

    private var filteredNotes: [LessonNote] {
        switch selectedFilter {
        case 0:
            return allNotes.filter { !$0.isCompleted }
        case 2:
            return allNotes.filter { $0.isCompleted }
        default:
            return allNotes
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdropView(reducedTransparency: reducedTransparency)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    headerCard
                        .padding(.horizontal)
                        .padding(.top, 8)

                    filterSegmentBar
                        .padding(.horizontal)

                    if filteredNotes.isEmpty {
                        emptyStateView
                            .padding(.horizontal)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredNotes) { note in
                                    noteCard(note)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("Задания и заметки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .fullScreenCover(item: $fullscreenPhoto) { item in
                FullscreenNotePhotoView(url: item.url)
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Задания и заметки")
                        .font(.headline.bold())
                        .foregroundColor(.primary)

                    Text("\(pendingCount)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundColor(pendingCount > 0 ? .white : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(pendingCount > 0 ? Color.accentColor : Color.secondary.opacity(0.2))
                        )
                }

                Text("Все заметки к парам в одном месте")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)
    }

    private var filterSegmentBar: some View {
        HStack(spacing: 6) {
            filterChip(title: "Активные", tag: 0)
            filterChip(title: "Все", tag: 1)
            filterChip(title: "Выполнено", tag: 2)
        }
        .padding(4)
        .liquidGlassCapsule(reducedTransparency: reducedTransparency)
    }

    private func filterChip(title: String, tag: Int) -> some View {
        let isSelected = (selectedFilter == tag)
        return Button {
            HapticsService.shared.selection()
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedFilter = tag
            }
        } label: {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            Capsule().fill(Color.accentColor)
                        } else {
                            Capsule().fill(Color.clear)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private var emptyStateView: some View {
        let title: String
        let showHint: Bool

        switch selectedFilter {
        case 0:
            if allNotes.isEmpty {
                title = "Заданий пока нет"
                showHint = true
            } else {
                title = "Все задания выполнены!"
                showHint = false
            }
        case 2:
            title = "Выполненных заданий пока нет"
            showHint = false
        default:
            title = "Заданий пока нет"
            showHint = true
        }

        return VStack(spacing: 10) {
            Image(systemName: selectedFilter == 0 && !allNotes.isEmpty ? "checkmark.seal.fill" : "note.text")
                .font(.system(size: 38))
                .foregroundColor(selectedFilter == 0 && !allNotes.isEmpty ? .uniLiveEmerald : .secondary)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            if showHint {
                Text("Нажмите на пару в расписании, чтобы добавить заметку или фото")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .liquidGlassCard(cornerRadius: 20, reducedTransparency: reducedTransparency)
        .padding(.top, 12)
    }

    private func noteCard(_ note: LessonNote) -> some View {
        let photoURL = repository.loadNotePhotoURL(path: note.imagePath)

        return HStack(alignment: .top, spacing: 12) {
            Button {
                HapticsService.shared.impact(.light)
                repository.setNoteCompleted(id: note.id, isCompleted: !note.isCompleted)
            } label: {
                Image(systemName: note.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(note.isCompleted ? .uniLiveEmerald : .secondary)
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(note.subjectName)
                    .font(.subheadline.bold())
                    .strikethrough(note.isCompleted)
                    .foregroundColor(note.isCompleted ? .secondary : .primary)
                    .opacity(note.isCompleted ? 0.65 : 1.0)
                    .multilineTextAlignment(.leading)

                Text("\(note.formattedDate) · \(note.lessonNumber) пара")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)

                let trimmedText = note.noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedText.isEmpty {
                    Text(trimmedText)
                        .font(.subheadline)
                        .strikethrough(note.isCompleted)
                        .foregroundColor(note.isCompleted ? .secondary : .primary)
                        .opacity(note.isCompleted ? 0.65 : 0.92)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }

                #if canImport(UIKit)
                if let photoURL, let uiImage = UIImage(contentsOfFile: photoURL.path) {
                    Button {
                        HapticsService.shared.selection()
                        fullscreenPhoto = FullscreenPhotoItem(url: photoURL)
                    } label: {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .destructive) {
                HapticsService.shared.notification(.warning)
                repository.deleteNote(date: note.dateString, lessonNumber: note.lessonNumber)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.red.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 18, reducedTransparency: reducedTransparency)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticsService.shared.selection()
            let targetDate = note.date ?? Date()
            dismiss()
            onNavigateToDate(targetDate)
        }
    }
}

private struct FullscreenPhotoItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct FullscreenNotePhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            #if canImport(UIKit)
            if let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                Text("Не удалось загрузить фото")
                    .foregroundColor(.white)
            }
            #else
            Text("Предпросмотр недоступен")
                .foregroundColor(.white)
            #endif

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(20)
            }
            .buttonStyle(.plain)
        }
    }
}
