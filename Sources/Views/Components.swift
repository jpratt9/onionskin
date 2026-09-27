import SwiftUI

/// The one filled button per screen: an accent pill.
struct PrimaryButton: View {
    let title: String
    let symbol: String
    let style: NoteStyle
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(style.onAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(style.accent.opacity(hovering ? 1 : 0.9)))
                .scaleEffect(hovering ? 1.03 : 1)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.25), value: hovering)
    }
}

/// Outlined button for secondary actions next to a primary one.
struct SecondaryButton: View {
    let title: String
    let style: NoteStyle
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovering ? style.heading : style.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(style.surface.opacity(hovering ? 1 : 0)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(style.border))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.25), value: hovering)
    }
}

/// Quiet text button ("Add item", "Add card", "Add idea") that brightens on hover.
struct GhostButton: View {
    let title: String
    let symbol: String
    let style: NoteStyle
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovering ? style.heading : style.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.25), value: hovering)
    }
}

/// Icon-only toolbar glyph with a hover plate; `active` marks a toggle that is on.
struct IconGlyph: View {
    let symbol: String
    let style: NoteStyle
    var active = false
    let hovering: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13))
            .foregroundStyle(active ? style.accent : hovering ? style.heading : style.secondary)
            .frame(width: 28, height: 28)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(style.surface.opacity(hovering ? 1 : 0)))
            .contentShape(Rectangle())
    }
}

struct IconButton: View {
    let label: String
    let symbol: String
    let style: NoteStyle
    var active = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) { IconGlyph(symbol: symbol, style: style, active: active, hovering: hovering) }
            .buttonStyle(.plain)
            .help(label)
            .accessibilityLabel(label)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.25), value: hovering)
    }
}

struct IconMenu<Content: View>: View {
    let label: String
    let symbol: String
    let style: NoteStyle
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    var body: some View {
        Menu(content: content) { IconGlyph(symbol: symbol, style: style, hovering: hovering) }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(label)
            .accessibilityLabel(label)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.25), value: hovering)
    }
}

/// Serif title at the top of lists, mind maps and boards.
struct TitleField: View {
    @Binding var title: String
    let placeholder: String
    let style: NoteStyle

    var body: some View {
        TextField(placeholder, text: $title)
            .textFieldStyle(.plain)
            .font(style.titleFont(size: 22))
            .tracking(-0.3)
            .foregroundStyle(style.heading)
    }
}

/// Drags the window from otherwise empty areas such as the toolbar.
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }

    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ view: NSView, context: Context) {}
}

/// Hands the hosting NSWindow to `configure` whenever SwiftUI updates this view.
struct WindowConfigurator: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    final class ConfiguringView: NSView {
        var configure: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { configure?(window) }
        }
    }

    func makeNSView(context: Context) -> ConfiguringView { ConfiguringView() }

    func updateNSView(_ view: ConfiguringView, context: Context) {
        view.configure = configure
        if let window = view.window { configure(window) }
    }
}

/// Letter shadow for the Halo theme.
struct HaloEffect: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.shadow(color: .black.opacity(0.9), radius: 1.5)
        } else {
            content
        }
    }
}

/// See-through tinted background, hairline edge, window level and traffic lights shared by every note window.
struct NoteWindowChrome: ViewModifier {
    @CurrentStyle private var style
    @AppStorage(Pref.opacity) private var opacity = 0.9
    @AppStorage(Pref.alwaysOnTop) private var alwaysOnTop = true
    @AppStorage(Pref.topBarHidden) private var toolbarHidden = false

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .foregroundStyle(style.text)
            .tint(style.accent)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: style.theme.background).opacity(opacity))
                    // The hairline keeps the note's outline visible when it's nearly transparent.
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(style.border))
                    .ignoresSafeArea()
            )
            .preferredColorScheme(style.theme.isDark ? .dark : .light)
            .background(WindowConfigurator { window in
                window.isOpaque = false
                window.backgroundColor = .clear
                window.level = alwaysOnTop ? .floating : .normal
                for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                    window.standardWindowButton(button)?.isHidden = toolbarHidden
                }
                window.invalidateShadow()
            })
    }
}
