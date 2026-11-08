import Foundation
import UIKit

/// Everything between "the user tapped Share" and "here is a draft".
///
/// 1. Safari's preprocessing snapshot of the live page, if we have one.
/// 2. Otherwise, load the URL in a hidden web view and run the same script.
/// 3. If the page has no structured product data and we're still thin,
///    ask LinkPresentation for a title and image.
/// 4. Still missing brand, model or price: the on-device Foundation Model
///    reads the page text.
/// 5. Convert foreign prices to pounds.
@MainActor
enum ExtractionPipeline {
    struct Outcome {
        var draft: ListingDraft
        var snapshotJSON: String?
        /// An image from a fallback that has bytes but no URL.
        var extraImage: Data?
        var steps: [String]
    }

    static func run(snapshotJSON: String?, url: URL?, host: UIView?) async -> Outcome {
        var steps: [String] = []
        var json = snapshotJSON
        var snapshot = json.flatMap(PageSnapshot.decode)
        if snapshot != nil {
            steps.append("safari")
        } else if let url {
            let reader = WebPageReader()
            if let read = await reader.snapshot(of: url, attachedTo: host) {
                snapshot = read.snapshot
                json = read.json
                steps.append("webview")
            } else {
                steps.append("webview-failed")
            }
        }

        var draft = snapshot.map(ListingInterpreter.interpret) ?? ListingDraft()
        if draft.sourceURL == nil { draft.sourceURL = url }
        if draft.siteName.isEmpty, var host = draft.sourceURL?.host() {
            if host.hasPrefix("www.") { host.removeFirst(4) }
            draft.siteName = host
        }
        if draft.pageTitle.isEmpty, let title = snapshot?.title, !title.isEmpty {
            ListingInterpreter.applyTitle(title, to: &draft)
        }

        var extraImage: Data?
        let structured = snapshot?.hasStructuredData ?? false
        if !structured, draft.isThin, let link = draft.sourceURL {
            if let preview = await LinkPreviewFallback.fetch(link) {
                steps.append("linkpresentation")
                draft.sources.insert(.linkPresentation)
                if let title = preview.title { ListingInterpreter.applyTitle(title, to: &draft) }
                extraImage = preview.imageData
            } else {
                steps.append("linkpresentation-failed")
            }
        }
        // On-device model over the page text, for pages the structure missed.
        if let text = snapshot?.text, text.count > 80,
           draft.brand.isEmpty || draft.model.isEmpty || (!structured && draft.price == nil) {
            let before = draft
            await FoundationModelsFallback.fill(&draft, title: snapshot?.title ?? draft.pageTitle, text: text)
            steps.append(draft == before ? "foundationmodels-nothing" : "foundationmodels")
        }

        // Prices are always pounds.
        if let price = draft.price, !price.isGBP {
            if let converted = await CurrencyConverter.toGBP(price) {
                draft.originalPrice = price
                draft.price = converted
                steps.append("converted-\(price.currency)")
            } else {
                steps.append("no-rate-\(price.currency)")
            }
        }

        return Outcome(draft: draft, snapshotJSON: json, extraImage: extraImage, steps: steps)
    }
}
