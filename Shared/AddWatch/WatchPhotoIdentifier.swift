import Foundation
import CoreGraphics
import UIKit
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Suggests what a photographed watch might be, entirely on the device.
/// Names printed on the dial are read first and can be trusted most. On
/// iPhones whose on-device model can see images, it adds its own guesses.
enum WatchPhotoIdentifier {
    private static let imagePixel = 1024
    private static let maximumSuggestions = 3

    static func suggestions(for photo: Data) async -> [WatchCatalog.Match] {
        guard let jpeg = ImageDownscaler.jpeg(from: photo, maxPixel: imagePixel),
              let image = UIImage(data: jpeg)?.cgImage else { return [] }
        let text = await dialText(in: image)
        var found = WatchCatalog.matches(inDialText: text)
        found += await visualGuesses(of: image, dialText: text)
        return merged(found)
    }

    /// Text the camera can see on the watch, one piece per line.
    static func dialText(in image: CGImage) async -> String {
        let request = RecognizeTextRequest()
        guard let observations = try? await request.perform(on: image) else { return "" }
        return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    /// Keeps a guess only if it names a real brand, and only names a model
    /// that brand really makes, so it can't invent a watch.
    static func grounded(brand: String, model: String) -> WatchCatalog.Match? {
        guard let name = WatchCatalog.knownBrand(brand) else { return nil }
        return WatchCatalog.Match(brand: name, model: WatchCatalog.knownModel(model, brand: name) ?? "")
    }

    /// One entry per watch, dropping a brand-only entry when a model is known.
    private static func merged(_ matches: [WatchCatalog.Match]) -> [WatchCatalog.Match] {
        var seen = Set<WatchCatalog.Match>()
        let unique = matches.filter { seen.insert($0).inserted }
        let specific = Set(unique.filter { !$0.model.isEmpty }.map(\.brand))
        return Array(unique.filter { !$0.model.isEmpty || !specific.contains($0.brand) }.prefix(maximumSuggestions))
    }

    private static func visualGuesses(of image: CGImage, dialText: String) async -> [WatchCatalog.Match] {
        #if canImport(FoundationModels)
        if #available(iOS 27.0, *) {
            return await modelGuesses(of: image, dialText: dialText)
        }
        #endif
        return []
    }
}

#if canImport(FoundationModels)
@Generable
struct WatchPhotoGuesses {
    @Guide(description: "The most likely watches in the photo, best first. Empty if it can't be told.", .maximumCount(3))
    var guesses: [WatchPhotoGuess]
}

@Generable
struct WatchPhotoGuess {
    @Guide(description: "The watch manufacturer, for example Omega or Seiko.")
    var brand: String
    @Guide(description: "The model family without the brand, for example Speedmaster Professional. Empty if unclear.")
    var model: String
}

extension WatchPhotoIdentifier {
    /// Gives up after a while, so the suggestions never hold up saving.
    @available(iOS 27.0, *)
    fileprivate static func modelGuesses(of image: CGImage, dialText: String) async -> [WatchCatalog.Match] {
        let language = SystemLanguageModel.default
        guard language.isAvailable, language.capabilities.contains(.vision) else { return [] }
        return await withTaskGroup(of: [WatchCatalog.Match]?.self) { group in
            group.addTask {
                let session = LanguageModelSession(model: language, instructions: """
                    You identify wristwatches from photos. Use the logo, any name on the dial, \
                    and the shape of the case, bezel and hands. Leave the list empty rather than guess wildly.
                    """)
                let prompt = Prompt {
                    "What watch is this? Text read from the dial: \(dialText.isEmpty ? "none" : dialText)"
                    Attachment(image)
                }
                guard let reply = try? await session.respond(to: prompt, generating: WatchPhotoGuesses.self).content else { return nil }
                return reply.guesses.compactMap { grounded(brand: $0.brand, model: $0.model) }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(20))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? []
        }
    }
}
#endif
