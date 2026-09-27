import XCTest
@testable import Onionskin

final class NoteTests: XCTestCase {
    func testTextNoteTitleIsItsFirstLine() {
        var note = Note(kind: .text)
        XCTAssertEqual(note.displayTitle, "Untitled note")
        note.text = "\n  Grocery run\n\nMilk, bread"
        XCTAssertEqual(note.displayTitle, "Grocery run")
    }

    func testNewStructuredNotesStartUntitled() {
        let list = Note(kind: .checklist)
        XCTAssertEqual(list.title, "")
        XCTAssertEqual(list.displayTitle, "Untitled list")
        XCTAssertEqual(Note(kind: .mindMap).displayTitle, "Untitled mind map")
    }

    func testPlainText() {
        var checklist = Note(kind: .checklist)
        checklist.title = "Standup"
        checklist.items = [ChecklistItem(text: "Blockers", done: true), ChecklistItem(text: "Demo")]
        XCTAssertEqual(checklist.plainText, "Standup\n[x] Blockers\n[ ] Demo")

        var map = Note(kind: .mindMap)
        map.title = "Launch plan"
        let root = MindNode(text: "Launch", x: 0, y: 0)
        map.nodes = [root, MindNode(text: "Pricing", x: 0, y: 0, parent: root.id)]
        XCTAssertEqual(map.plainText, "Launch plan\n- Launch\n  - Pricing")

        var board = Note(kind: .board)
        board.title = "Kitchen"
        board.columns = [BoardColumn(title: "To order", cards: [BoardCard(text: "Tiles")])]
        XCTAssertEqual(board.plainText, "Kitchen\n\nTo order\n- Tiles")
    }

    func testRelativeTimestamp() {
        let now = Date()
        XCTAssertEqual(Note.relativeTimestamp(now.addingTimeInterval(-30), now: now), "Just now")
        let earlier = Note.relativeTimestamp(now.addingTimeInterval(-7200), now: now)
        XCTAssertNotEqual(earlier, "Just now")
        XCTAssertTrue(earlier.contains("2"), earlier)
    }

    func testStyleRunsSurviveFontAndThemeChanges() {
        let runs = [StyleRun(location: 0, length: 7, bold: true), StyleRun(location: 8, length: 5, italic: true, underline: true)]
        for (family, theme) in [(NoteStyle.systemFamily, Theme.carbon), ("Helvetica Neue", Theme.named("Halo"))] {
            let font = NoteStyle(theme: theme, fontFamily: family, fontSize: 16).nsFont()
            let string = RichText.attributedString(text: "Lecture notes from Tuesday", styles: runs, font: font, theme: theme)
            XCTAssertEqual(RichText.styleRuns(from: string), runs, family)
        }
    }

    func testTextExportIsRTF() throws {
        var note = Note(kind: .text)
        note.text = "Lecture notes"
        note.styles = [StyleRun(location: 0, length: 7, bold: true)]
        let data = try Exporter.data(for: note)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).hasPrefix("{\\rtf1"))
    }
}
