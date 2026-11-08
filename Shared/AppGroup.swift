import Foundation

/// Identifiers shared by the app and the share extension.
///
/// The values come from Config/Crowns.xcconfig via each target's Info.plist,
/// so the bundle prefix is set in exactly one place.
enum AppGroup {
    static let identifier: String = info("CrownsAppGroup") ?? "group.com.kadeashiq.crowns"
    static let cloudKitContainer: String = info("CrownsCloudKitContainer") ?? "iCloud.com.kadeashiq.crowns"

    /// The shared container. Nil only when the App Group entitlement is
    /// missing, which is a signing problem, not something to recover from
    /// silently; callers log it.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static let defaults: UserDefaults = UserDefaults(suiteName: identifier) ?? .standard

    private static func info(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }
}

enum SharedKeys {
    static let lastBoxID = "lastBoxID"
    static let externalSaveStamp = "externalSaveStamp"
}
