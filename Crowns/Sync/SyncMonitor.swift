import Foundation
import CoreData
import CloudKit
import Observation

/// Watches iCloud: whether the account is usable, and the import/export
/// events SwiftData's CloudKit mirroring reports.
@MainActor
@Observable
final class SyncMonitor {
    enum Account: Equatable { case unknown, available, signedOut, restricted, unavailable }

    private(set) var account: Account = .unknown
    private(set) var lastImport: Date?
    private(set) var lastExport: Date?
    private(set) var lastError: String?
    private(set) var syncing = false

    /// Runs after each import, to merge default boxes seeded on two devices.
    @ObservationIgnored var onImport: (@MainActor () -> Void)?
    @ObservationIgnored private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
            MainActor.assumeIsolated { self?.handle(event) }
        }
    }

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        guard let end = event.endDate else {
            syncing = true
            return
        }
        syncing = false
        if let error = event.error {
            lastError = (error as NSError).localizedDescription
            return
        }
        lastError = nil
        switch event.type {
        case .import:
            lastImport = end
            onImport?()
        case .export:
            lastExport = end
        default:
            break
        }
    }

    func checkAccount() async {
        do {
            let status = try await CKContainer(identifier: AppGroup.cloudKitContainer).accountStatus()
            switch status {
            case .available: account = .available
            case .noAccount: account = .signedOut
            case .restricted: account = .restricted
            default: account = .unavailable
            }
        } catch {
            account = .unavailable
        }
    }

    var lastSync: Date? {
        [lastImport, lastExport].compactMap { $0 }.max()
    }

    var statusText: String {
        switch account {
        case .unknown: return "Checking"
        case .signedOut: return "Off. Sign in to iCloud"
        case .restricted, .unavailable: return "Unavailable"
        case .available:
            if syncing { return "Syncing" }
            if lastError != nil { return "Error" }
            return "On"
        }
    }
}
