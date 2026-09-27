import AppKit

/// Converts between a text note's stored form (plain text + style runs) and what the editor shows.
/// Font family, size and colors are never stored, so Settings changes apply to every note.
enum RichText {
    static func attributedString(text: String, styles: [StyleRun], font: NSFont, theme: Theme) -> NSAttributedString {
        let string = NSMutableAttributedString(string: text, attributes: baseAttributes(font: font, theme: theme))
        let manager = NSFontManager.shared
        for run in styles where run.location + run.length <= string.length {
            let range = NSRange(location: run.location, length: run.length)
            var runFont = font
            if run.bold { runFont = manager.convert(runFont, toHaveTrait: .boldFontMask) }
            if run.italic { runFont = manager.convert(runFont, toHaveTrait: .italicFontMask) }
            string.addAttribute(.font, value: runFont, range: range)
            if run.underline { string.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
        }
        return string
    }

    static func baseAttributes(font: NSFont, theme: Theme) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.25
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: theme.text, .paragraphStyle: paragraph]
        if theme.halo {
            let shadow = NSShadow()
            shadow.shadowColor = .black
            shadow.shadowBlurRadius = 3
            attributes[.shadow] = shadow
        }
        return attributes
    }

    static func styleRuns(from string: NSAttributedString) -> [StyleRun] {
        var runs: [StyleRun] = []
        string.enumerateAttributes(in: NSRange(location: 0, length: string.length)) { attributes, range, _ in
            let traits = (attributes[.font] as? NSFont).map { NSFontManager.shared.traits(of: $0) } ?? []
            let run = StyleRun(location: range.location, length: range.length,
                               bold: traits.contains(.boldFontMask),
                               italic: traits.contains(.italicFontMask),
                               underline: (attributes[.underlineStyle] as? Int ?? 0) != 0)
            if run.bold || run.italic || run.underline { runs.append(run) }
        }
        return runs
    }
}
