import Foundation

/// Lets the app notice watches the share extension saved while it was in the
/// background. The extension stamps a shared date; the app compares on
/// foreground. A Darwin notification covers the case where the app is
/// running at the same time (e.g. side by side on iPad).
enum ExternalChanges {
    static let darwinName = "com.crowns.store.didChange"

    static func markChanged() {
        AppGroup.defaults.set(Date().timeIntervalSince1970, forKey: SharedKeys.externalSaveStamp)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(darwinName as CFString), nil, nil, true)
    }

    static var stamp: TimeInterval {
        AppGroup.defaults.double(forKey: SharedKeys.externalSaveStamp)
    }
}
