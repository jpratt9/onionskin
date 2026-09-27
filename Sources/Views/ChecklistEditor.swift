import SwiftUI

/// List: a serif title, a progress line, and rows with square checkboxes. Return in a row starts the next one.
struct ChecklistEditor: View {
    @Binding var note: Note
    let style: NoteStyle
    @FocusState private var focusedItem: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TitleField(title: $note.title, placeholder: "Untitled list", style: style)
                Text(progress)
                    .font(.system(size: 12))
                    .foregroundStyle(style.secondary)
                    .padding(.top, 4)
                    .padding(.bottom, 14)
                ForEach($note.items) { $item in
                    ChecklistRow(item: $item, style: style, focusedItem: $focusedItem,
                                 onReturn: { insert(after: item.id) },
                                 onDelete: { note.items.removeAll { $0.id == item.id } })
                }
                GhostButton(title: "Add item", symbol: "plus", style: style) { insert(after: nil) }
                    .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }

    private var progress: String {
        note.items.isEmpty ? "No items yet" : "\(note.items.filter(\.done).count) of \(note.items.count) done"
    }

    /// Adds an empty item after `id` (or at the end) and puts the cursor in it.
    private func insert(after id: UUID?) {
        let item = ChecklistItem()
        let index = id.flatMap { id in note.items.firstIndex { $0.id == id } }.map { $0 + 1 } ?? note.items.endIndex
        note.items.insert(item, at: index)
        // The field only exists after this update.
        DispatchQueue.main.async { focusedItem = item.id }
    }
}

struct ChecklistRow: View {
    @Binding var item: ChecklistItem
    let style: NoteStyle
    var focusedItem: FocusState<UUID?>.Binding
    let onReturn: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Button { withAnimation(.spring(duration: 0.25)) { item.done.toggle() } } label: {
                CheckBox(done: item.done, style: style)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.done ? "Mark as not done" : "Mark as done")
            TextField("New item", text: $item.text)
                .textFieldStyle(.plain)
                .font(style.font())
                .foregroundStyle(item.done ? style.secondary : style.text)
                .focused(focusedItem, equals: item.id)
                .onSubmit(onReturn)
            Button(action: onDelete) { Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)) }
                .buttonStyle(.plain)
                .foregroundStyle(style.secondary)
                .opacity(hovering ? 1 : 0)
                .help("Delete item")
                .accessibilityLabel("Delete item")
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(style.border).frame(height: 1) }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.2), value: hovering)
        .contextMenu { Button("Delete", role: .destructive, action: onDelete) }
    }
}

/// Rounded-square checkbox, filled with the accent once done.
struct CheckBox: View {
    let done: Bool
    let style: NoteStyle

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(done ? style.accent : .clear)
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(done ? style.accent : style.secondary, lineWidth: 1.5))
            .overlay {
                if done {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(style.onAccent)
                }
            }
            .frame(width: 18, height: 18)
    }
}
