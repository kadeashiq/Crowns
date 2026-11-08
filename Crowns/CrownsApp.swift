import SwiftUI
import SwiftData

@main
struct CrownsApp: App {
    private let container = SharedStore.appContainer()
    @State private var sync = SyncMonitor()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(sync)
                .tint(Theme.ink)
        }
        .modelContainer(container)
    }
}
