import SwiftUI

/// UserDefaults keys shared by windows, menus and Settings.
enum Pref {
    static let theme = "theme"
    static let fontFamily = "fontFamily"
    static let fontSize = "fontSize"
    static let opacity = "opacity"
    static let alwaysOnTop = "alwaysOnTop"
    static let topBarHidden = "topBarHidden"
    static let sidebarHidden = "sidebarHidden"
    static let selectedNote = "selectedNote"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            theme: Theme.carbon.name,
            fontFamily: NoteStyle.systemFamily,
            fontSize: 16.0,
            opacity: 0.9,
            alwaysOnTop: true,
            topBarHidden: false,
            sidebarHidden: false,
        ])
    }
}

/// Theme and font every note editor draws with.
struct NoteStyle: Equatable {
    static let systemFamily = "System"

    var theme: Theme
    var fontFamily: String
    var fontSize: Double

    /// Read straight from UserDefaults, for code outside views.
    static var current: NoteStyle {
        let defaults = UserDefaults.standard
        return NoteStyle(theme: .named(defaults.string(forKey: Pref.theme) ?? ""),
                         fontFamily: defaults.string(forKey: Pref.fontFamily) ?? systemFamily,
                         fontSize: defaults.double(forKey: Pref.fontSize))
    }

    func nsFont(size: Double? = nil, bold: Bool = false) -> NSFont {
        let size = CGFloat(size ?? fontSize)
        var font = fontFamily == Self.systemFamily ? .systemFont(ofSize: size)
            : NSFontManager.shared.font(withFamily: fontFamily, traits: [], weight: 5, size: size) ?? .systemFont(ofSize: size)
        if bold { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
        return font
    }

    func font(size: Double? = nil, bold: Bool = false) -> Font { Font(nsFont(size: size, bold: bold) as CTFont) }

    /// Titles use New York, the system serif: a manuscript voice for a paper-named app. Views add tight tracking.
    func titleFont(size: Double) -> Font { .system(size: size, weight: .semibold, design: .serif) }

    var heading: Color { Color(nsColor: theme.heading) }
    var text: Color { Color(nsColor: theme.text) }
    var secondary: Color { Color(nsColor: theme.secondary) }
    var accent: Color { Color(nsColor: theme.accent) }
    var onAccent: Color { Color(nsColor: theme.onAccent) }
    var surface: Color { Color(nsColor: theme.surface) }
    var border: Color { Color(nsColor: theme.border) }
}

/// The current `NoteStyle`, updating views when Settings change.
@propertyWrapper
struct CurrentStyle: DynamicProperty {
    @AppStorage(Pref.theme) private var theme = Theme.carbon.name
    @AppStorage(Pref.fontFamily) private var fontFamily = NoteStyle.systemFamily
    @AppStorage(Pref.fontSize) private var fontSize = 16.0

    var wrappedValue: NoteStyle { NoteStyle(theme: .named(theme), fontFamily: fontFamily, fontSize: fontSize) }
}
