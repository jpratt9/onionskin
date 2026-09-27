import SwiftUI

@main
struct OnionskinApp: App {
    @State private var store = NoteStore()
    @State private var speaker = Speaker()

    init() {
        Pref.registerDefaults()
    }

    var body: some Scene {
        Window("Onionskin", id: "main") {
            MainView()
                .environment(store)
                .environment(speaker)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 760, height: 480)
        .commands { NoteCommands(store: store) }

        WindowGroup("Note", id: "note", for: UUID.self) { $noteID in
            NoteWindow(noteID: noteID)
                .environment(store)
                .environment(speaker)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 460, height: 420)

        Settings {
            SettingsView()
        }
    }
}
