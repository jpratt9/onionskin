import AppKit

/// Format menu actions (Bold ⌘B, Italic ⌘I, Underline ⌘U) for the focused text-note editor.
enum TextFormatting {
    /// SwiftUI text fields use plain field editors, so only note editors qualify.
    private static var focusedEditor: NSTextView? {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView, textView.isRichText, textView.isEditable else { return nil }
        return textView
    }

    static func toggleUnderline() {
        focusedEditor?.underline(nil)
    }

    static func toggle(_ trait: NSFontTraitMask) {
        guard let textView = focusedEditor else { return }
        let manager = NSFontManager.shared
        let range = textView.selectedRange()
        guard range.length > 0 else {
            if let font = textView.typingAttributes[.font] as? NSFont {
                textView.typingAttributes[.font] = convert(font, trait, adding: !manager.traits(of: font).contains(trait))
            }
            return
        }
        guard let storage = textView.textStorage, textView.shouldChangeText(in: range, replacementString: nil) else { return }
        let firstFont = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
        let adding = !(firstFont.map { manager.traits(of: $0).contains(trait) } ?? false)
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            if let font = value as? NSFont {
                storage.addAttribute(.font, value: convert(font, trait, adding: adding), range: subrange)
            }
        }
        storage.endEditing()
        textView.didChangeText()
    }

    private static func convert(_ font: NSFont, _ trait: NSFontTraitMask, adding: Bool) -> NSFont {
        adding ? NSFontManager.shared.convert(font, toHaveTrait: trait) : NSFontManager.shared.convert(font, toNotHaveTrait: trait)
    }
}
