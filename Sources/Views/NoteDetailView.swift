import SwiftUI

extension NoteStore {
    /// Writes edits back through `update`; nil once the note is gone.
    func binding(for id: UUID) -> Binding<Note>? {
        guard let current = note(id) else { return nil }
        return Binding(get: { self.note(id) ?? current }, set: { self.update($0) })
    }
}

/// One note under its toolbar; used by the main window and by "Open in New Window".
struct NoteDetailView: View {
    let noteID: UUID
    /// Only the main window has a notes list to bring back.
    var showsListToggle = false
    @Environment(NoteStore.self) private var store
    @AppStorage(Pref.topBarHidden) private var toolbarHidden = false
    @CurrentStyle private var style
    @State private var focus = false

    var body: some View {
        if let note = store.binding(for: noteID) {
            VStack(spacing: 0) {
                if toolbarHidden {
                    CollapsedToolbar(style: style)
                } else {
                    NoteToolbar(note: note.wrappedValue, showsListToggle: showsListToggle, focus: $focus)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                editor(note)
            }
            .animation(.easeInOut(duration: 0.25), value: toolbarHidden)
        }
    }

    @ViewBuilder
    private func editor(_ note: Binding<Note>) -> some View {
        switch note.wrappedValue.kind {
        case .text:
            // Focus: larger, read-only text in a centered column, for reading while presenting.
            TextNoteEditor(note: note,
                           font: style.nsFont(size: focus ? style.fontSize * 1.35 : nil),
                           theme: style.theme,
                           readOnly: focus)
                .frame(maxWidth: focus ? 720 : .infinity)
        case .checklist:
            ChecklistEditor(note: note, style: style).modifier(HaloEffect(enabled: style.theme.halo))
        case .mindMap:
            MindMapEditor(note: note, style: style).modifier(HaloEffect(enabled: style.theme.halo))
        case .board:
            BoardEditor(note: note, style: style).modifier(HaloEffect(enabled: style.theme.halo))
        }
    }
}

/// Icon toolbar: list toggle on the left; dictate, read aloud, focus, share, more and collapse on the right.
struct NoteToolbar: View {
    let note: Note
    let showsListToggle: Bool
    @Binding var focus: Bool
    @Environment(NoteStore.self) private var store
    @Environment(Speaker.self) private var speaker
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Pref.topBarHidden) private var toolbarHidden = false
    @AppStorage(Pref.sidebarHidden) private var sidebarHidden = false
    @CurrentStyle private var style
    @State private var showDetails = false
    @State private var cloudFailed = false

    var body: some View {
        HStack(spacing: 2) {
            if showsListToggle && sidebarHidden {
                IconButton(label: "Show notes list", symbol: "sidebar.left", style: style) { sidebarHidden = false }
            }
            Spacer()
            if note.kind == .text {
                IconButton(label: "Dictate", symbol: "mic", style: style) {
                    NotificationCenter.default.post(name: .startDictation, object: note.id)
                }
                IconButton(label: speaker.isSpeaking ? "Stop reading" : "Read aloud",
                           symbol: speaker.isSpeaking ? "stop.circle" : "speaker.wave.2",
                           style: style, active: speaker.isSpeaking) { speaker.toggle(note.plainText) }
                IconButton(label: focus ? "Leave focus" : "Focus", symbol: "eyeglasses", style: style, active: focus) {
                    focus.toggle()
                }
            }
            IconMenu(label: "Share", symbol: "square.and.arrow.up", style: style) {
                ShareLink("Share…", item: note.plainText)
                Button("Export…") { Exporter.export(note) }
            }
            IconMenu(label: "More", symbol: "ellipsis.circle", style: style) {
                Button("Details") { showDetails = true }
                Toggle("Sync with iCloud Drive", isOn: Binding(get: { note.inICloud },
                                                              set: { cloudFailed = !store.setICloud($0, for: note.id) }))
                Button("Open in New Window") { openWindow(id: "note", value: note.id) }
                Divider()
                Button("Delete…", role: .destructive) { Confirm.delete(note, from: store) }
            }
            .popover(isPresented: $showDetails) { NoteDetails(note: note, style: style) }
            IconButton(label: "Collapse toolbar", symbol: "chevron.up", style: style) { toolbarHidden = true }
        }
        // Clears the traffic lights when no notes list sits under them.
        .padding(.leading, showsListToggle && !sidebarHidden ? 12 : 76)
        .padding(.trailing, 12)
        .frame(height: 44)
        .background(WindowDragArea())
        .alert("Couldn't move the note to iCloud Drive", isPresented: $cloudFailed) {
            Button("OK") {}
        } message: {
            Text("Make sure iCloud Drive is turned on in System Settings and Onionskin may access it.")
        }
    }
}

/// Collapsed toolbar: a thin draggable strip whose grabber brings the toolbar back.
struct CollapsedToolbar: View {
    let style: NoteStyle
    @AppStorage(Pref.topBarHidden) private var toolbarHidden = false
    @State private var hovering = false

    var body: some View {
        ZStack {
            WindowDragArea()
            Button { toolbarHidden = false } label: {
                Capsule()
                    .fill(style.secondary.opacity(hovering ? 0.9 : 0.25))
                    .frame(width: 36, height: 5)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Show toolbar")
            .accessibilityLabel("Show toolbar")
        }
        .frame(height: 18)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.2), value: hovering)
    }
}

struct NoteDetails: View {
    let note: Note
    let style: NoteStyle

    var body: some View {
        let text = note.plainText
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
            row("Type", note.kind.label)
            row("Created", note.created.formatted(date: .abbreviated, time: .shortened))
            row("Edited", note.modified.formatted(date: .abbreviated, time: .shortened))
            row("Words", "\(text.split(whereSeparator: \.isWhitespace).count)")
            row("Characters", "\(text.count)")
            row("Stored", note.inICloud ? "iCloud Drive" : "This Mac")
        }
        .font(.system(size: 12))
        .padding(16)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(style.secondary)
            Text(value).foregroundStyle(style.heading)
        }
    }
}

/// A single note in its own window, without the notes list.
struct NoteWindow: View {
    let noteID: UUID?
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var note: Note? { noteID.flatMap(store.note) }

    var body: some View {
        ZStack {
            if let note {
                NoteDetailView(noteID: note.id)
            }
        }
        .frame(minWidth: 380, minHeight: 220)
        .modifier(NoteWindowChrome())
        .focusedSceneValue(\.activeNoteID, noteID)
        .navigationTitle(note?.displayTitle ?? "Note")
        // Close once the note is deleted, including windows restored at launch for notes deleted since.
        .onChange(of: note == nil, initial: true) { _, deleted in
            if deleted { dismiss() }
        }
    }
}
