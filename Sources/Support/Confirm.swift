import AppKit

enum Confirm {
    /// Asks before deleting, as a sheet on the key window so it stays above floating notes.
    static func delete(_ note: Note, from store: NoteStore) {
        let alert = NSAlert()
        alert.messageText = "Delete “\(note.displayTitle)”?"
        alert.informativeText = "This can't be undone."
        alert.addButton(withTitle: "Delete").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        let handle = { (response: NSApplication.ModalResponse) in
            if response == .alertFirstButtonReturn { store.delete(note.id) }
        }
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }
}
