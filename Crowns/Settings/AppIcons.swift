import UIKit

/// The app icons in this build. To add one, drop a `.icon` file with no spaces
/// in its name into Crowns/Icons and run Tools/gen_xcodeproj.py.
enum AppIcons {
    /// Nil is the primary icon, matching `UIApplication.alternateIconName`.
    static var all: [String?] {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let alternates = icons?["CFBundleAlternateIcons"] as? [String: Any] ?? [:]
        return [nil] + alternates.keys.sorted()
    }

    /// File names can't have spaces, so a few read better spelled out.
    private static let titles = ["Blue": "Midnight Blue"]

    static func title(_ name: String?) -> String { name.map { titles[$0] ?? $0 } ?? "Green" }

    static func preview(_ name: String?) -> String { "IconPreview-\(name ?? "Green")" }
}
