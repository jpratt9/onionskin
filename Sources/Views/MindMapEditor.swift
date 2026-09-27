import SwiftUI

/// Mind map: idea chips joined to their parent by curved connectors.
/// Click selects, drag moves, double-click a chip renames it, double-click the canvas adds an idea there.
struct MindMapEditor: View {
    @Binding var note: Note
    let style: NoteStyle
    @State private var selection: UUID?
    @State private var editing: UUID?
    @State private var drag: (id: UUID, offset: CGSize)?
    @FocusState private var focusedNode: UUID?

    private static let chip = CGSize(width: 150, height: 46)
    private static let rootChip = CGSize(width: 170, height: 54)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                TitleField(title: $note.title, placeholder: "Untitled mind map", style: style)
                GhostButton(title: "Add idea", symbol: "plus", style: style) { addNode(at: nil) }
            }
            .padding(.horizontal, 24)
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2, coordinateSpace: .local) { addNode(at: $0) }
                            .onTapGesture { selection = nil; editing = nil }
                        Path { path in
                            for node in note.nodes {
                                guard let parent = note.nodes.first(where: { $0.id == node.parent }) else { continue }
                                path.addPath(connector(from: frame(of: parent), to: frame(of: node)))
                            }
                        }
                        .stroke(style.secondary.opacity(0.6), lineWidth: 1.2)
                        ForEach($note.nodes) { $node in
                            chip($node).position(center(of: node))
                        }
                        if note.nodes.isEmpty {
                            Text("Double-click anywhere to add your first idea")
                                .font(.system(size: 13))
                                .foregroundStyle(style.secondary)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(width: max(geometry.size.width, (note.nodes.map(\.x).max() ?? 0) + Self.rootChip.width),
                           height: max(geometry.size.height, (note.nodes.map(\.y).max() ?? 0) + Self.rootChip.height))
                }
                .scrollIndicators(.never)
            }
        }
        .padding(.top, 8)
    }

    private func chip(_ node: Binding<MindNode>) -> some View {
        let id = node.wrappedValue.id
        let isRoot = node.wrappedValue.parent == nil
        let selected = selection == id
        let size = isRoot ? Self.rootChip : Self.chip
        return ZStack {
            if editing == id {
                TextField("Idea", text: node.text)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .focused($focusedNode, equals: id)
                    .onSubmit { editing = nil }
            } else {
                Text(node.wrappedValue.text.isEmpty ? "Untitled idea" : node.wrappedValue.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .font(isRoot ? style.titleFont(size: 15) : style.font(size: 13))
        .foregroundStyle(isRoot ? style.heading : style.text)
        .padding(.horizontal, 12)
        .frame(width: size.width, height: size.height)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(style.surface))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(selected ? style.accent : style.border, lineWidth: selected ? 1.5 : 1))
        // The glow marks the one selected idea, the focus of the next "Add idea".
        .shadow(color: selected ? style.accent.opacity(0.35) : .clear, radius: 8)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(count: 2) { startEditing(id) }
        .onTapGesture { selection = id; if editing != id { editing = nil } }
        .gesture(DragGesture(minimumDistance: 3)
            .onChanged { drag = (id, $0.translation) }
            .onEnded { value in
                node.wrappedValue.x = max(size.width / 2, node.wrappedValue.x + value.translation.width)
                node.wrappedValue.y = max(size.height / 2, node.wrappedValue.y + value.translation.height)
                drag = nil
            })
        .contextMenu {
            Button("Rename") { startEditing(id) }
            Button("Delete", role: .destructive) { delete(id) }
        }
        .animation(.easeOut(duration: 0.2), value: selected)
    }

    private func center(of node: MindNode) -> CGPoint {
        let offset = drag?.id == node.id ? drag?.offset ?? .zero : .zero
        return CGPoint(x: node.x + offset.width, y: node.y + offset.height)
    }

    private func frame(of node: MindNode) -> CGRect {
        let size = node.parent == nil ? Self.rootChip : Self.chip
        let center = center(of: node)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    /// An S-curve from the facing edges of two chips, horizontal or vertical depending on how they sit.
    private func connector(from parent: CGRect, to child: CGRect) -> Path {
        var path = Path()
        let dx = child.midX - parent.midX, dy = child.midY - parent.midY
        if abs(dx) >= abs(dy) {
            let start = CGPoint(x: dx > 0 ? parent.maxX : parent.minX, y: parent.midY)
            let end = CGPoint(x: dx > 0 ? child.minX : child.maxX, y: child.midY)
            let middle = (start.x + end.x) / 2
            path.move(to: start)
            path.addCurve(to: end, control1: CGPoint(x: middle, y: start.y), control2: CGPoint(x: middle, y: end.y))
        } else {
            let start = CGPoint(x: parent.midX, y: dy > 0 ? parent.maxY : parent.minY)
            let end = CGPoint(x: child.midX, y: dy > 0 ? child.minY : child.maxY)
            let middle = (start.y + end.y) / 2
            path.move(to: start)
            path.addCurve(to: end, control1: CGPoint(x: start.x, y: middle), control2: CGPoint(x: end.x, y: middle))
        }
        return path
    }

    /// Adds an idea under the selection (or the root) and starts renaming it.
    /// `point` places it where the canvas was double-clicked; otherwise it takes the first free spot around its parent.
    private func addNode(at point: CGPoint?) {
        let parent = note.nodes.first { $0.id == selection } ?? note.nodes.first { $0.parent == nil }
        let minX = Double(Self.chip.width) / 2, minY = Double(Self.chip.height) / 2
        let clearX = Double(Self.rootChip.width) + 10, clearY = Double(Self.rootChip.height) + 10
        var node = MindNode(x: 260, y: 180, parent: parent?.id)
        if let point {
            node.x = max(minX, Double(point.x))
            node.y = max(minY, Double(point.y))
        } else if let parent {
            let spots: [(x: Double, y: Double)] = (0..<12).map { step in
                let angle = Double(step) * .pi / 6
                return (max(minX, parent.x + cos(angle) * 220), max(minY, parent.y + sin(angle) * 120))
            }
            let spot = spots.first { spot in
                note.nodes.allSatisfy { abs($0.x - spot.x) > clearX || abs($0.y - spot.y) > clearY }
            } ?? spots[0]
            node.x = spot.x
            node.y = spot.y
        }
        note.nodes.append(node)
        startEditing(node.id)
    }

    private func startEditing(_ id: UUID) {
        selection = id
        editing = id
        // The text field only exists after this update, so focus it on the next run-loop turn.
        DispatchQueue.main.async { focusedNode = id }
    }

    /// Removes an idea; its children move up to its parent.
    private func delete(_ id: UUID) {
        let parent = note.nodes.first { $0.id == id }?.parent
        var nodes = note.nodes.filter { $0.id != id }
        for index in nodes.indices where nodes[index].parent == id { nodes[index].parent = parent }
        note.nodes = nodes
        if selection == id { selection = nil }
    }
}
