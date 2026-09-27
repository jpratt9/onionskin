import Foundation
import Observation
import OSLog

/// All notes in memory, newest edit first. Each note is mirrored to its own JSON file,
/// in Application Support or, once moved to iCloud, in the app's iCloud Drive folder.
@Observable
final class NoteStore {
    private(set) var notes: [Note] = []
    /// Last failed save, shown in the main window until dismissed.
    var saveError: String?
    let localDirectory: URL
    let cloudDirectory: URL?
    @ObservationIgnored private let log = Logger(subsystem: "com.jpratt9.Onionskin", category: "NoteStore")

    init(localDirectory: URL = NoteStore.defaultLocalDirectory, cloudDirectory: URL? = NoteStore.defaultCloudDirectory) {
        self.localDirectory = localDirectory
        self.cloudDirectory = cloudDirectory
        reload()
    }

    static var defaultLocalDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Onionskin/Notes", directoryHint: .isDirectory)
    }

    /// Synced between Macs by iCloud Drive; nil when iCloud Drive is turned off.
    static var defaultCloudDirectory: URL? {
        let drive = URL.homeDirectory.appending(path: "Library/Mobile Documents/com~apple~CloudDocs", directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: drive.path(percentEncoded: false)) else { return nil }
        return drive.appending(path: "Onionskin", directoryHint: .isDirectory)
    }

    /// Re-reads every note file, picking up changes synced from other Macs.
    func reload() {
        let decoder = JSONDecoder()
        let files: [URL] = [localDirectory, cloudDirectory].compactMap { $0 }
            .flatMap { (try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? [] }
        let loaded: [Note] = files.filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(Note.self, from: Data(contentsOf: $0)) }
        var seen = Set<UUID>()
        notes = loaded.sorted { $0.modified > $1.modified }.filter { seen.insert($0.id).inserted }
    }

    func note(_ id: UUID) -> Note? { notes.first { $0.id == id } }

    @discardableResult
    func create(_ kind: NoteKind) -> Note {
        let note = Note(kind: kind)
        notes.insert(note, at: 0)
        save(note)
        return note
    }

    /// Saves an edited note. Only content changes bump `modified` and move the note to the top;
    /// opening a note never does.
    func update(_ note: Note) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }), notes[index] != note else { return }
        var note = note
        if !note.hasSameContent(as: notes[index]) { note.modified = .now }
        notes[index] = note
        notes.sort { $0.modified > $1.modified }
        save(note)
    }

    func delete(_ id: UUID) {
        guard let note = note(id) else { return }
        try? FileManager.default.removeItem(at: fileURL(for: note))
        notes.removeAll { $0.id == id }
    }

    /// Moves a note's file between this Mac and iCloud Drive. Returns false if it couldn't be moved.
    @discardableResult
    func setICloud(_ enabled: Bool, for id: UUID) -> Bool {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return false }
        guard notes[index].inICloud != enabled else { return true }
        guard !enabled || cloudDirectory != nil else { return false }
        var moved = notes[index]
        moved.inICloud = enabled
        do {
            try write(moved)
        } catch {
            log.error("Moving note to \(enabled ? "iCloud" : "local") failed: \(error)")
            return false
        }
        try? FileManager.default.removeItem(at: fileURL(for: notes[index]))
        notes[index] = moved
        return true
    }

    private func fileURL(for note: Note) -> URL {
        let directory = note.inICloud ? cloudDirectory ?? localDirectory : localDirectory
        return directory.appending(path: "\(note.id.uuidString).json")
    }

    private func write(_ note: Note) throws {
        let url = fileURL(for: note)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(note).write(to: url, options: .atomic)
    }

    private func save(_ note: Note) {
        do {
            try write(note)
        } catch {
            log.error("Saving note \(note.id) failed: \(error)")
            saveError = "Couldn't save “\(note.displayTitle)”: \(error.localizedDescription)"
        }
    }
}
