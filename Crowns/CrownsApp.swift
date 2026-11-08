import SwiftUI
import SwiftData

@main
struct CrownsApp: App {
    private let container = SharedStore.appContainer()
    @State private var toast = ToastCenter()
    @State private var sync = SyncMonitor()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(toast)
                .environment(sync)
                .environment(ProStore.shared)
                .preferredColorScheme(.dark)
                .tint(Theme.brass)
        }
        .modelContainer(container)
    }
}
