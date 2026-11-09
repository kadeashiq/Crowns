import SwiftData
import Observation

/// Owns the app's store, and reopens it when iCloud sync is switched on or off.
@MainActor
@Observable
final class StoreHost {
    private(set) var container: ModelContainer
    @ObservationIgnored private var openedWithSync = SharedStore.syncEnabled

    init() {
        container = SharedStore.appContainer()
    }

    /// Called when Settings closes, so the switch happens out of sight.
    func applySyncSetting() {
        guard SharedStore.syncEnabled != openedWithSync else { return }
        openedWithSync = SharedStore.syncEnabled
        container = SharedStore.appContainer()
    }
}
