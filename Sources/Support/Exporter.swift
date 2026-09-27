import AppKit
import UniformTypeIdentifiers

/// Export: text notes become RTF (keeping bold/italic/underline), checklists plain text.
enum Exporter {
    static func export(_ note: Note) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = note.displayTitle.replacingOccurrences(of: "/", with: "-")
        panel.allowedContentTypes = [note.kind == .text ? .rtf : .plainText]
        let write = { (url: URL) in
            do {
                try data(for: note).write(to: url, options: .atomic)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window) { response in
                if response == .OK, let url = panel.url { write(url) }
            }
        } else if panel.runModal() == .OK, let url = panel.url {
            write(url)
        }
    }

    static func data(for note: Note) throws -> Data {
        guard note.kind == .text else { return Data(note.plainText.utf8) }
        let string = RichText.attributedString(text: note.text, styles: note.styles, font: NoteStyle.current.nsFont(), theme: .paper)
        return try string.data(from: NSRange(location: 0, length: string.length),
                               documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }
}
