import AppKit

/// A note color scheme. The background fades with the transparency setting; text never does.
struct Theme: Identifiable, Equatable {
    let name: String
    let background: NSColor
    let heading: NSColor
    let text: NSColor
    let secondary: NSColor
    /// Selection, checked items, the caret and the one filled button per screen.
    let accent: NSColor
    /// Soft dark shadow behind letters so text stays legible over busy windows.
    let halo: Bool

    private init(_ name: String, background: UInt32, heading: UInt32, text: UInt32, secondary: UInt32, accent: UInt32, halo: Bool = false) {
        self.name = name
        self.background = NSColor(hex: background)
        self.heading = NSColor(hex: heading)
        self.text = NSColor(hex: text)
        self.secondary = NSColor(hex: secondary)
        self.accent = NSColor(hex: accent)
        self.halo = halo
    }

    var id: String { name }
    var isDark: Bool { (background.usingColorSpace(.sRGB)?.brightnessComponent ?? 1) < 0.5 }
    /// Columns, cards and chips: a translucent layer over the note, like a second sheet of onionskin.
    var surface: NSColor { .white.withAlphaComponent(isDark ? 0.05 : 0.6) }
    var border: NSColor { heading.withAlphaComponent(isDark ? 0.10 : 0.12) }
    /// Text on the accent; dark on the icy dark-theme accent, white on the deeper light-theme one.
    var onAccent: NSColor { isDark ? NSColor(hex: 0x0F0F11) : .white }

    static let carbon = Theme("Carbon", background: 0x141416, heading: 0xFFFFFF, text: 0xD4D4D8, secondary: 0xA1A1AA, accent: 0x9CBBD4)
    /// Dark ink on warm paper; also used for exports so they read on any page.
    static let paper = Theme("Paper", background: 0xF3EFE6, heading: 0x1C1917, text: 0x292524, secondary: 0x57534E, accent: 0x3E6A8A)

    static let all: [Theme] = [
        carbon,
        Theme("Slate", background: 0x171B22, heading: 0xF1F5F9, text: 0xCBD5E1, secondary: 0x94A3B8, accent: 0xA8D0E6),
        Theme("Ink", background: 0x0E1424, heading: 0xFFFFFF, text: 0xD6E2F0, secondary: 0x9AA8BF, accent: 0x9CBBD4),
        Theme("Halo", background: 0x0F0F11, heading: 0xFFFFFF, text: 0xF4F4F5, secondary: 0xA1A1AA, accent: 0xA8D0E6, halo: true),
        Theme("Fog", background: 0xEEF1F4, heading: 0x0F0F11, text: 0x27272A, secondary: 0x52525B, accent: 0x3E6A8A),
        paper,
    ]

    static func named(_ name: String) -> Theme { all.first { $0.name == name } ?? carbon }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
