import SwiftUI
import SwiftData

@main
struct CrownsApp: App {
    private let container = SharedStore.appContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
