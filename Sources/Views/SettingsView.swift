import SwiftUI

enum AppLinks {
    static let repository = URL(string: "https://github.com/jpratt9/onionskin")!
}

/// Settings: a section list on the left, cards on the right, always in the Carbon palette.
struct SettingsView: View {
    enum Section: String, CaseIterable, Identifiable {
        case window = "Window", appearance = "Appearance", typography = "Typography", about = "About"

        var id: Self { self }

        var symbol: String {
            switch self {
            case .window: "macwindow.on.rectangle"
            case .appearance: "circle.lefthalf.filled"
            case .typography: "textformat"
            case .about: "info.circle"
            }
        }
    }

    @State private var section = Section.window
    @AppStorage(Pref.alwaysOnTop) private var alwaysOnTop = true
    private let style = NoteStyle(theme: .carbon, fontFamily: NoteStyle.systemFamily, fontSize: 13)

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Section.allCases) { item in
                    SettingsNavRow(title: item.rawValue, symbol: item.symbol, selected: section == item, style: style) {
                        section = item
                    }
                }
                Spacer()
            }
            .padding(10)
            .frame(width: 176)
            .background(style.surface)
            Rectangle().fill(style.border).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(section.rawValue)
                        .font(style.titleFont(size: 22))
                        .tracking(-0.3)
                        .foregroundStyle(style.heading)
                    switch section {
                    case .window: WindowSettings(style: style)
                    case .appearance: AppearanceSettings(style: style)
                    case .typography: TypographySettings(style: style)
                    case .about: AboutSettings(style: style)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 640, height: 460)
        .background(Color(nsColor: style.theme.background))
        .foregroundStyle(style.text)
        .tint(style.accent)
        .preferredColorScheme(.dark)
        // Stay above floating notes.
        .background(WindowConfigurator { $0.level = alwaysOnTop ? .floating : .normal })
    }
}

struct SettingsNavRow: View {
    let title: String
    let symbol: String
    let selected: Bool
    let style: NoteStyle
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? style.heading : style.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? style.accent.opacity(0.16) : style.surface.opacity(hovering ? 1 : 0)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.2), value: hovering)
    }
}

struct SettingsCard<Content: View>: View {
    let style: NoteStyle
    let content: Content

    init(style: NoteStyle, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(style.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(style.border))
    }
}

struct WindowSettings: View {
    let style: NoteStyle
    @AppStorage(Pref.opacity) private var opacity = 0.9
    @AppStorage(Pref.alwaysOnTop) private var alwaysOnTop = true
    @AppStorage(Pref.topBarHidden) private var toolbarHidden = false
    @AppStorage(Pref.sidebarHidden) private var sidebarHidden = false

    var body: some View {
        SettingsCard(style: style) {
            HStack {
                Text("Transparency").foregroundStyle(style.heading)
                Spacer()
                Text("\(Int(((1 - opacity) * 100).rounded()))%").monospacedDigit().foregroundStyle(style.secondary)
            }
            Slider(value: Binding(get: { 1 - opacity }, set: { opacity = 1 - $0 }), in: 0...0.9)
                .accessibilityLabel("Transparency")
            Text("How much of the windows behind shows through. Text always stays solid.")
                .font(.system(size: 11))
                .foregroundStyle(style.secondary)
        }
        SettingsCard(style: style) {
            Toggle("Float above other windows", isOn: $alwaysOnTop)
            Toggle("Show toolbar", isOn: Binding(get: { !toolbarHidden }, set: { toolbarHidden = !$0 }))
            Toggle("Show notes list", isOn: Binding(get: { !sidebarHidden }, set: { sidebarHidden = !$0 }))
        }
        .toggleStyle(.switch)
    }
}

struct AppearanceSettings: View {
    let style: NoteStyle
    @AppStorage(Pref.theme) private var theme = Theme.carbon.name

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
            ForEach(Theme.all) { option in
                ThemeSwatch(theme: option, selected: theme == option.name, style: style) { theme = option.name }
            }
        }
    }
}

/// A miniature note in the theme's own colors: serif title, body line, accent bar.
struct ThemeSwatch: View {
    let theme: Theme
    let selected: Bool
    let style: NoteStyle
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Agenda")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(Color(nsColor: theme.heading))
                    Text("Intro, updates, Q&A")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(nsColor: theme.text))
                    Capsule().fill(Color(nsColor: theme.accent)).frame(width: 22, height: 4)
                }
                .modifier(HaloEffect(enabled: theme.halo))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: theme.background)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? style.accent : hovering ? style.secondary : style.border, lineWidth: selected ? 2 : 1))
                Text(theme.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(selected ? style.heading : style.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.2), value: hovering)
        .accessibilityLabel("\(theme.name) theme")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct TypographySettings: View {
    let style: NoteStyle
    @AppStorage(Pref.fontFamily) private var fontFamily = NoteStyle.systemFamily
    @AppStorage(Pref.fontSize) private var fontSize = 16.0
    private let families = [NoteStyle.systemFamily] + NSFontManager.shared.availableFontFamilies

    var body: some View {
        SettingsCard(style: style) {
            Picker("Font", selection: $fontFamily) {
                ForEach(families, id: \.self) { Text($0).tag($0) }
            }
            Stepper(value: $fontSize, in: 11...32, step: 1) {
                HStack {
                    Text("Size")
                    Spacer()
                    Text("\(Int(fontSize)) pt").monospacedDigit().foregroundStyle(style.secondary)
                }
            }
        }
        SettingsCard(style: style) {
            Text("Preview").font(.system(size: 11, weight: .medium)).foregroundStyle(style.secondary)
            Text("The quick brown fox jumps over the lazy dog.")
                .font(NoteStyle(theme: .carbon, fontFamily: fontFamily, fontSize: fontSize).font())
                .foregroundStyle(style.heading)
        }
    }
}

struct AboutSettings: View {
    let style: NoteStyle
    @Environment(\.openURL) private var openURL

    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }

    var body: some View {
        SettingsCard(style: style) {
            Text("Onionskin \(version)").font(style.titleFont(size: 17)).foregroundStyle(style.heading)
            Text("Notes you can see through, kept above your other windows.")
                .foregroundStyle(style.secondary)
            HStack(spacing: 10) {
                SecondaryButton(title: "View source", style: style) { openURL(AppLinks.repository) }
                SecondaryButton(title: "Report an issue", style: style) { openURL(AppLinks.repository.appending(path: "issues/new")) }
            }
        }
    }
}
