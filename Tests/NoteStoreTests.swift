import XCTest
@testable import Onionskin

final class NoteStoreTests: XCTestCase {
    private var root: URL!
    private var local: URL { root.appending(path: "local") }
    private var cloud: URL { root.appending(path: "cloud") }

    override func setUp() {
        root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeStore(cloud: URL? = nil) -> NoteStore {
        NoteStore(localDirectory: local, cloudDirectory: cloud ?? self.cloud)
    }

    func testNotesPersistAcrossLaunches() {
        let store = makeStore()
        var note = store.create(.checklist)
        note.items = [ChecklistItem(text: "Blockers")]
        store.update(note)
        XCTAssertEqual(makeStore().note(note.id)?.items.map(\.text), ["Blockers"])
    }

    func testOpeningWithoutEditingKeepsOrderAndDate() {
        let store = makeStore()
        let older = store.create(.text)
        let newer = store.create(.text)
        store.update(store.note(older.id)!)
        XCTAssertEqual(store.notes.map(\.id), [newer.id, older.id])
        XCTAssertEqual(store.note(older.id)?.modified, older.modified)
    }

    func testEditingMovesNoteToTop() {
        let store = makeStore()
        var older = store.create(.text)
        let newer = store.create(.text)
        older.text = "Lecture notes"
        store.update(older)
        XCTAssertEqual(store.notes.map(\.id), [older.id, newer.id])
        XCTAssertGreaterThan(store.notes[0].modified, newer.modified)
    }

    func testDeleteRemovesTheFile() {
        let store = makeStore()
        let note = store.create(.board)
        store.delete(note.id)
        XCTAssertNil(store.note(note.id))
        XCTAssertNil(makeStore().note(note.id))
    }

    func testICloudMovesTheFileBothWays() throws {
        let store = makeStore()
        let note = store.create(.text)
        let fileName = "\(note.id.uuidString).json"

        XCTAssertTrue(store.setICloud(true, for: note.id))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: cloud.path(percentEncoded: false)), [fileName])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: local.path(percentEncoded: false)), [])
        XCTAssertEqual(makeStore().note(note.id)?.inICloud, true)

        XCTAssertTrue(store.setICloud(false, for: note.id))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: local.path(percentEncoded: false)), [fileName])
        XCTAssertEqual(makeStore().notes.count, 1)
    }

    func testICloudRefusedWithoutICloudDrive() {
        let store = NoteStore(localDirectory: local, cloudDirectory: nil)
        let note = store.create(.text)
        XCTAssertFalse(store.setICloud(true, for: note.id))
        XCTAssertEqual(store.note(note.id)?.inICloud, false)
    }
}
