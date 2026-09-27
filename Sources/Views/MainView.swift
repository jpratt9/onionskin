import SwiftUI

/// Main window: notes list on the left, the selected note on the right.
struct MainView: View {
    @Environment(NoteStore.self) private var store
    @AppStorage(Pref.selectedNote) private var selectedNote = ""
    @AppStorage(Pref.sidebarHidden) private var sidebarHidden = false
    @CurrentStyle private var style

    /// The remembered selection, else the most recently edited note.
    private var selection: UUID? {
        UUID(uuidString: selectedNote).flatMap { store.note($0)?.id } ?? store.notes.first?.id
    }

    var body: some View {
        HStack(spacing: 0) {
            if !sidebarHidden {
                Sidebar(selection: selection, select: select)
                    .frame(width: 240)
                Rectangle().fill(style.border).frame(width: 1)
            }
            ZStack {
                if let selection {
                    NoteDetailView(noteID: selection, showsListToggle: true)
                        .id(selection)
                        .transition(.opacity)
                } else {
                    EmptyNotesView { select(store.create($0).id) }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 320)
        .overlay(alignment: .bottom) {
            if let error = store.saveError {
                SaveErrorBanner(message: error, style: style) { store.saveError = nil }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: store.saveError)
        .modifier(NoteWindowChrome())
        .focusedSceneValue(\.activeNoteID, selection)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.reload()
        }
    }

    private func select(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) { selectedNote = id.uuidString }
    }
}

/// Shown until the first note exists.
struct EmptyNotesView: View {
    let create: (NoteKind) -> Void
    @CurrentStyle private var style

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing here yet")
                .font(style.titleFont(size: 26))
                .tracking(-0.4)
                .foregroundStyle(style.heading)
            Text("Notes float above your other windows, so you can read them during a call or next to a document.")
                .font(.system(size: 13))
                .foregroundStyle(style.secondary)
                .frame(maxWidth: 340, alignment: .leading)
            HStack(spacing: 10) {
                PrimaryButton(title: "New note", symbol: "plus", style: style) { create(.text) }
                ForEach([NoteKind.checklist, .mindMap, .board]) { kind in
                    SecondaryButton(title: kind.label, style: style) { create(kind) }
                }
            }
            .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowDragArea())
    }
}

/// Error state for a failed save: what failed and a way to dismiss it.
struct SaveErrorBanner: View {
    let message: String
    let style: NoteStyle
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
            Text(message).lineLimit(2)
            Spacer(minLength: 8)
            Button("Dismiss", action: dismiss)
                .buttonStyle(.plain)
                .foregroundStyle(style.accent)
        }
        .font(.system(size: 12))
        .foregroundStyle(style.heading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: style.theme.background)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.red.opacity(0.6)))
        .padding(16)
    }
}
