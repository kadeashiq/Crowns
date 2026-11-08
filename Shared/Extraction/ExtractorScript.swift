import Foundation

/// Preprocess.js, bundled into both the app and the extension.
enum ExtractorScript {
    static let source: String = {
        guard let url = Bundle.main.url(forResource: "Preprocess", withExtension: "js"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Preprocess.js missing from bundle")
            return ""
        }
        return text
    }()
}
