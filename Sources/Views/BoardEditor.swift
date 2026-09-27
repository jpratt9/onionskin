import SwiftUI

/// Board: columns of cards. Drag a card by its grip (or use its context menu) to move it.
struct BoardEditor: View {
    @Binding var note: Note
    let style: NoteStyle
    @FocusState private var focusedColumn: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TitleField(title: $note.title, placeholder: "Untitled board", style: style)
                .padding(.horizontal, 24)
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach($note.columns) { $column in
                        BoardColumnView(column: $column,
                                        style: style,
                                        otherColumns: note.columns.filter { $0.id != column.id },
                                        focusedColumn: $focusedColumn,
                                        delete: { note.columns.removeAll { $0.id == column.id } },
                                        move: moveCard)
                    }
                    AddColumnTile(style: style) {
                        let column = BoardColumn()
                        note.columns.append(column)
                        DispatchQueue.main.async { focusedColumn = column.id }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .padding(.top, 8)
    }

    /// Moves a card into `columnID`, before `beforeCard` or at the end.
    private func moveCard(_ cardID: UUID, to columnID: UUID, before beforeCard: UUID?) {
        guard cardID != beforeCard, let card = note.columns.lazy.flatMap(\.cards).first(where: { $0.id == cardID }) else { return }
        var columns = note.columns
        for index in columns.indices { columns[index].cards.removeAll { $0.id == cardID } }
        guard let target = columns.firstIndex(where: { $0.id == columnID }) else { return }
        let position = beforeCard.flatMap { id in columns[target].cards.firstIndex { $0.id == id } } ?? columns[target].cards.endIndex
        columns[target].cards.insert(card, at: position)
        note.columns = columns
    }
}

struct BoardColumnView: View {
    @Binding var column: BoardColumn
    let style: NoteStyle
    let otherColumns: [BoardColumn]
    var focusedColumn: FocusState<UUID?>.Binding
    let delete: () -> Void
    let move: (_ card: UUID, _ column: UUID, _ before: UUID?) -> Void
    @FocusState private var focusedCard: UUID?
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Column name", text: $column.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(style.heading)
                    .focused(focusedColumn, equals: column.id)
                Text("\(column.cards.count)")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(style.secondary)
                    .accessibilityLabel("\(column.cards.count) cards")
                IconMenu(label: "Column actions", symbol: "ellipsis", style: style) {
                    Button("Delete Column", role: .destructive, action: delete)
                }
            }
            ForEach($column.cards) { $card in
                BoardCardView(card: $card,
                              style: style,
                              otherColumns: otherColumns,
                              focusedCard: $focusedCard,
                              delete: { column.cards.removeAll { $0.id == card.id } },
                              moveTo: { move(card.id, $0, nil) })
                    .dropDestination(for: String.self) { ids, _ in
                        ids.compactMap(UUID.init(uuidString:)).forEach { move($0, column.id, card.id) }
                        return true
                    }
            }
            GhostButton(title: "Add card", symbol: "plus", style: style) {
                let card = BoardCard()
                column.cards.append(card)
                DispatchQueue.main.async { focusedCard = card.id }
            }
            .padding(.top, 2)
        }
        .padding(12)
        .frame(width: 236, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(style.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(dropTargeted ? style.accent : style.border))
        .dropDestination(for: String.self) { ids, _ in
            ids.compactMap(UUID.init(uuidString:)).forEach { move($0, column.id, nil) }
            return true
        } isTargeted: { dropTargeted = $0 }
        .animation(.easeOut(duration: 0.2), value: dropTargeted)
    }
}

struct BoardCardView: View {
    @Binding var card: BoardCard
    let style: NoteStyle
    let otherColumns: [BoardColumn]
    var focusedCard: FocusState<UUID?>.Binding
    let delete: () -> Void
    let moveTo: (UUID) -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            TextField("New card", text: $card.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(style.font(size: min(style.fontSize, 15)))
                .lineLimit(1...8)
                .focused(focusedCard, equals: card.id)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11))
                .foregroundStyle(style.secondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
                .opacity(hovering ? 1 : 0)
                .draggable(card.id.uuidString)
                .help("Drag to move")
                .accessibilityHidden(true)
        }
        .padding(10)
        .frame(minHeight: 48, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(style.surface))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(hovering ? style.accent.opacity(0.5) : style.border))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.2), value: hovering)
        .contextMenu {
            if !otherColumns.isEmpty {
                Menu("Move To") {
                    ForEach(otherColumns) { column in
                        Button(column.title.isEmpty ? "Untitled column" : column.title) { moveTo(column.id) }
                    }
                }
            }
            Button("Delete Card", role: .destructive, action: delete)
        }
    }
}

/// Dashed tile at the end of the columns that adds a new one.
struct AddColumnTile: View {
    let style: NoteStyle
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label("Add column", systemImage: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovering ? style.heading : style.secondary)
                .frame(width: 200, height: 46)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(hovering ? style.accent.opacity(0.6) : style.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.2), value: hovering)
    }
}
