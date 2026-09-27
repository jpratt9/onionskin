import SwiftUI

struct ActiveNoteKey: FocusedValueKey {
    typealias Value = UUID
}

extension FocusedValues {
    /// The note shown in the key window, for menu actions.
    var activeNoteID: UUID? {
        get { self[ActiveNoteKey.self] }
        set { self[ActiveNoteKey.self] = newValue }
    }
}

/// File, Format and View menu items.
struct NoteCommands: Commands {
    let store: NoteStore
    @FocusedValue(\.activeNoteID) private var activeNoteID
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Pref.selectedNote) private var selectedNote = ""
    @AppStorage(Pref.alwaysOnTop) private var alwaysOnTop = true
    @AppStorage(Pref.opacity) private var opacity = 0.9
    @AppStorage(Pref.topBarHidden) private var topBarHidden = false
    @AppStorage(Pref.sidebarHidden) private var sidebarHidden = false

    private var activeNote: Note? { activeNoteID.flatMap(store.note) }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            ForEach(NoteKind.allCases) { kind in
                Button("New \(kind.label)") { create(kind) }
                    .keyboardShortcut(kind == .text ? KeyboardShortcut("n") : nil)
            }
            Divider()
            Button("Open in New Window") { if let activeNoteID { openWindow(id: "note", value: activeNoteID) } }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(activeNoteID == nil)
        }
        CommandGroup(replacing: .importExport) {
            Button("Export…") { if let activeNote { Exporter.export(activeNote) } }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(activeNote == nil)
            // No shortcut: ⌘⌫ must keep deleting to the start of the line while typing.
            Button("Delete Note…") { if let activeNote { Confirm.delete(activeNote, from: store) } }
                .disabled(activeNote == nil)
        }
        CommandMenu("Format") {
            Button("Bold") { TextFormatting.toggle(.boldFontMask) }.keyboardShortcut("b")
            Button("Italic") { TextFormatting.toggle(.italicFontMask) }.keyboardShortcut("i")
            Button("Underline") { TextFormatting.toggleUnderline() }.keyboardShortcut("u")
        }
        CommandGroup(before: .toolbar) {
            Toggle("Float Above Other Windows", isOn: $alwaysOnTop)
                .keyboardShortcut("a", modifiers: [.command, .option])
            Button("More Transparent") { setOpacity(opacity - 0.1) }.keyboardShortcut("[")
            Button("Less Transparent") { setOpacity(opacity + 0.1) }.keyboardShortcut("]")
            Divider()
            Button(topBarHidden ? "Show Toolbar" : "Hide Toolbar") { topBarHidden.toggle() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Button(sidebarHidden ? "Show Notes List" : "Hide Notes List") { sidebarHidden.toggle() }
                .keyboardShortcut("s", modifiers: [.command, .control])
            Divider()
        }
    }

    private func create(_ kind: NoteKind) {
        selectedNote = store.create(kind).id.uuidString
        openWindow(id: "main")
    }

    private func setOpacity(_ value: Double) {
        opacity = (min(1, max(0.1, value)) * 100).rounded() / 100
    }
}
