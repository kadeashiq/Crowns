import SwiftUI
import SwiftData

@main
struct CrownsApp: App {
    @State private var store = StoreHost()
    @State private var sync = SyncMonitor()

    var body: some Scene {
        WindowGroup {
            MainView()
                // A reopened store means a new context for everything below.
                .id(ObjectIdentifier(store.container))
                .environment(store)
                .environment(sync)
                .tint(Theme.ink)
                .modelContainer(store.container)
        }
    }
}
