import Foundation
import UniformTypeIdentifiers

struct ShareInput {
    /// JSON from Preprocess.js, present when shared from Safari.
    var snapshotJSON: String?
    /// The page URL. From Safari alongside the snapshot; from other apps alone.
    var url: URL?
}

enum ShareInputReader {
    static func read(_ items: [NSExtensionItem]) async -> ShareInput {
        var input = ShareInput()
        for item in items {
            for provider in item.attachments ?? [] {
                if input.snapshotJSON == nil,
                   let dict = await load(.propertyList, from: provider, as: NSDictionary.self),
                   let results = dict[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary,
                   let json = results["snapshot"] as? String {
                    input.snapshotJSON = json
                }
                if input.url == nil, let url = await load(.url, from: provider, as: URL.self), isWeb(url) {
                    input.url = url
                }
                if input.url == nil, let text = await load(.plainText, from: provider, as: String.self) {
                    input.url = firstLink(in: text)
                }
            }
            if input.url == nil, let text = item.attributedContentText?.string {
                input.url = firstLink(in: text)
            }
        }
        if input.url == nil, let json = input.snapshotJSON, let page = PageSnapshot.decode(json)?.pageURL {
            input.url = page
        }
        return input
    }

    private static func load<T>(_ type: UTType, from provider: NSItemProvider, as _: T.Type) async -> T? {
        guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { return nil }
        let item = try? await provider.loadItem(forTypeIdentifier: type.identifier, options: nil)
        return item as? T
    }

    static func firstLink(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap(\.url).first(where: isWeb)
    }

    private static func isWeb(_ url: URL) -> Bool {
        url.scheme == "https" || url.scheme == "http"
    }
}
