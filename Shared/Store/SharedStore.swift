import Foundation
import SwiftData
import os

/// The one SwiftData store, living in the App Group so the share extension
/// and the app read and write the same file.
///
/// Only the app mirrors to CloudKit. The extension opens the same store
/// without CloudKit: it is short-lived and memory-limited, and the app's
/// mirroring exports anything the extension wrote (via persistent history)
/// the next time it runs.
enum SharedStore {
    static let schema = Schema(versionedSchema: CrownsSchemaV1.self)
    static let log = Logger(subsystem: "Crowns", category: "store")

    static var storeURL: URL {
        let base: URL
        if let group = AppGroup.containerURL {
            base = group.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        } else {
            log.fault("App Group \(AppGroup.identifier, privacy: .public) unavailable; check signing. Using a private store.")
            base = URL.applicationSupportDirectory
        }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appending(path: "Crowns.store")
    }

    /// The app's container, syncing with iCloud. Falls back to a local-only
    /// store if CloudKit can't be set up (no iCloud entitlement, simulator
    /// without an account), so the app always opens.
    static func appContainer() -> ModelContainer {
        let cloud = ModelConfiguration("Crowns", schema: schema, url: storeURL, cloudKitDatabase: .private(AppGroup.cloudKitContainer))
        do {
            return try ModelContainer(for: schema, migrationPlan: CrownsMigrationPlan.self, configurations: cloud)
        } catch {
            log.error("CloudKit store failed, opening locally: \(error.localizedDescription, privacy: .public)")
        }
        return localContainer()
    }

    /// The extension's container: same file, no CloudKit.
    static func extensionContainer() -> ModelContainer {
        localContainer()
    }

    private static func localContainer() -> ModelContainer {
        let local = ModelConfiguration("Crowns", schema: schema, url: storeURL, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, migrationPlan: CrownsMigrationPlan.self, configurations: local)
        } catch {
            log.fault("Store failed to open: \(error.localizedDescription, privacy: .public)")
            let memory = ModelConfiguration("Crowns-memory", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            // An in-memory store with this schema cannot fail to open.
            return try! ModelContainer(for: schema, configurations: memory)
        }
    }
}
