import SwiftUI

extension Notification.Name {
    /// Posted by the Transcribe button with a note id; that note's editor starts macOS dictation.
    static let startDictation = Notification.Name("Onionskin.startDictation")
}

/// Pastes as plain text so pasted fonts and colors never override the theme.
final class NoteTextView: NSTextView {
    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] { [.string] }
}

/// Rich-text editor for text notes (bold, italic, underline) on a transparent background.
struct TextNoteEditor: NSViewRepresentable {
    @Binding var note: Note
    let font: NSFont
    let theme: Theme
    let readOnly: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NoteTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        let textView = scrollView.documentView as! NoteTextView
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 19, height: 8)
        context.coordinator.observeDictation(for: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let coordinator = context.coordinator
        coordinator.parent = self
        textView.isEditable = !readOnly
        // Accent caret and selection: easy to find on a see-through page.
        textView.insertionPointColor = theme.accent
        textView.selectedTextAttributes = [.backgroundColor: theme.accent.withAlphaComponent(0.3)]

        let shown = textView.attributedString()
        let contentChanged = shown.string != note.text || RichText.styleRuns(from: shown) != note.styles
        guard contentChanged || coordinator.shownFont != font || coordinator.shownTheme != theme else { return }
        // Only reload when the note changed underneath (sync) or Settings changed, never while typing.
        let selection = textView.selectedRanges.map(\.rangeValue)
        if contentChanged { textView.undoManager?.removeAllActions() }
        textView.textStorage?.setAttributedString(RichText.attributedString(text: note.text, styles: note.styles, font: font, theme: theme))
        textView.typingAttributes = RichText.baseAttributes(font: font, theme: theme)
        let length = textView.textStorage?.length ?? 0
        textView.selectedRanges = selection.map { range in
            let location = min(range.location, length)
            return NSValue(range: NSRange(location: location, length: min(range.length, length - location)))
        }
        coordinator.shownFont = font
        coordinator.shownTheme = theme
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextNoteEditor
        var shownFont: NSFont?
        var shownTheme: Theme?
        private var dictationObserver: NSObjectProtocol?

        init(_ parent: TextNoteEditor) {
            self.parent = parent
        }

        deinit {
            if let dictationObserver { NotificationCenter.default.removeObserver(dictationObserver) }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            var note = parent.note
            note.text = textView.string
            note.styles = RichText.styleRuns(from: textView.attributedString())
            parent.note = note
        }

        func observeDictation(for textView: NSTextView) {
            dictationObserver = NotificationCenter.default.addObserver(forName: .startDictation, object: nil, queue: .main) { [weak self, weak textView] notification in
                guard let self, let textView, textView.isEditable, let window = textView.window, window.isKeyWindow,
                      notification.object as? UUID == self.parent.note.id else { return }
                window.makeFirstResponder(textView)
                // The same action as Edit > Start Dictation; NSApplication handles it for the first responder.
                NSApp.sendAction(Selector(("startDictation:")), to: nil, from: textView)
            }
        }
    }
}
