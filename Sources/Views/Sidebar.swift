import SwiftUI

/// Notes list, newest edit first, under a header with Settings and the New menu.
struct Sidebar: View {
    let selection: UUID?
    let select: (UUID) -> Void
    @Environment(NoteStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Pref.topBarHidden) private var toolbarHidden = false
    @CurrentStyle private var style

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Notes")
                    .font(style.titleFont(size: 17))
                    .tracking(-0.2)
                    .foregroundStyle(style.heading)
                Spacer()
                SettingsLink { Image(systemName: "gearshape").font(.system(size: 13)).frame(width: 28, height: 28) }
                    .buttonStyle(.plain)
                    .foregroundStyle(style.secondary)
                    .help("Settings")
                Menu {
                    ForEach(NoteKind.allCases) { kind in
                        Button { select(store.create(kind).id) } label: { Label("New \(kind.label)", systemImage: kind.symbol) }
                    }
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(style.onAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(style.accent))
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("New note")
            }
            .padding(.horizontal, 14)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(store.notes) { note in
                        SidebarRow(note: note, selected: note.id == selection, style: style) { select(note.id) }
                            .contextMenu {
                                Button("Open in New Window") { openWindow(id: "note", value: note.id) }
                                Button("Delete…", role: .destructive) { Confirm.delete(note, from: store) }
                            }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.top, toolbarHidden ? 16 : 44)
        .background(WindowDragArea())
    }
}

struct SidebarRow: View {
    let note: Note
    let selected: Bool
    let style: NoteStyle
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(note.displayTitle)
                .font(.system(size: 13, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? style.heading : style.text)
                .lineLimit(1)
            HStack(spacing: 6) {
                // The type tag replaces an icon: it names the note's kind in words.
                Text(note.kind.tag)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(style.surface))
                    .overlay(Capsule().strokeBorder(style.border))
                if note.inICloud { Image(systemName: "icloud").accessibilityLabel("In iCloud Drive") }
                TimelineView(.everyMinute) { context in
                    Text(Note.relativeTimestamp(note.modified, now: context.date))
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(style.secondary)
        }
        .modifier(HaloEffect(enabled: style.theme.halo))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selected ? style.accent.opacity(0.16) : style.surface.opacity(hovering ? 1 : 0)))
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.2), value: hovering)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
