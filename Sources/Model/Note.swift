import Foundation

enum NoteKind: String, Codable, CaseIterable, Identifiable {
    case text, checklist, mindMap, board

    var id: Self { self }

    var label: String {
        switch self {
        case .text: "Note"
        case .checklist: "List"
        case .mindMap: "Mind Map"
        case .board: "Board"
        }
    }

    /// Short type tag shown in the notes list.
    var tag: String {
        switch self {
        case .text: "Text"
        case .checklist: "List"
        case .mindMap: "Map"
        case .board: "Board"
        }
    }

    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .checklist: "checklist"
        case .mindMap: "point.3.connected.trianglepath.dotted"
        case .board: "rectangle.split.3x1"
        }
    }
}

/// Bold/italic/underline applied to a UTF-16 range of a text note.
struct StyleRun: Codable, Equatable {
    var location: Int
    var length: Int
    var bold = false
    var italic = false
    var underline = false
}

struct ChecklistItem: Codable, Equatable, Identifiable {
    var id = UUID()
    var text = ""
    var done = false
}

struct MindNode: Codable, Equatable, Identifiable {
    var id = UUID()
    var text = ""
    var x: Double
    var y: Double
    var parent: UUID?
}

struct BoardCard: Codable, Equatable, Identifiable {
    var id = UUID()
    var text = ""
}

struct BoardColumn: Codable, Equatable, Identifiable {
    var id = UUID()
    var title = ""
    var cards: [BoardCard] = []
}

struct Note: Codable, Equatable, Identifiable {
    var id = UUID()
    var kind: NoteKind
    var title = ""
    var text = ""
    var styles: [StyleRun] = []
    var items: [ChecklistItem] = []
    var nodes: [MindNode] = []
    var columns: [BoardColumn] = []
    var created: Date
    var modified: Date
    var inICloud = false

    init(kind: NoteKind, date: Date = .now) {
        self.kind = kind
        created = date
        modified = date
    }

    /// Title shown in the notes list: a text note's first line, otherwise its title.
    var displayTitle: String {
        let name = kind == .text ? text.split(whereSeparator: \.isNewline).lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } : title
        return name.flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled \(kind.label.lowercased())"
    }

    /// Everything but timestamps and storage location, to tell real edits from merely opening a note.
    func hasSameContent(as other: Note) -> Bool {
        kind == other.kind && title == other.title && text == other.text && styles == other.styles
            && items == other.items && nodes == other.nodes && columns == other.columns
    }

    /// Plain-text rendering used by Export, Share, Speech and Info.
    var plainText: String {
        switch kind {
        case .text:
            text
        case .checklist:
            ([title] + items.map { ($0.done ? "[x] " : "[ ] ") + $0.text }).joined(separator: "\n")
        case .mindMap:
            ([title] + outline(under: nil, depth: 0)).joined(separator: "\n")
        case .board:
            ([title] + columns.flatMap { ["", $0.title] + $0.cards.map { "- " + $0.text } }).joined(separator: "\n")
        }
    }

    private func outline(under parent: UUID?, depth: Int) -> [String] {
        nodes.filter { $0.parent == parent }.flatMap {
            [String(repeating: "  ", count: depth) + "- " + $0.text] + outline(under: $0.id, depth: depth + 1)
        }
    }

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        return formatter
    }()

    /// Notes list date: "Just now" for the last minute, then relative ("5 min. ago", "yesterday").
    static func relativeTimestamp(_ date: Date, now: Date) -> String {
        now.timeIntervalSince(date) < 60 ? "Just now" : relative.localizedString(for: date, relativeTo: now)
    }
}
