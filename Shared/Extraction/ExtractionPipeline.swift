import Foundation
import UIKit

/// Everything between "the user tapped Share" and a finished draft.
///
/// What the page itself says comes first, and opens the form:
/// 1. Safari's preprocessing snapshot of the live page, if we have one.
/// 2. Otherwise, load the URL in a hidden web view and run the same script.
///
/// The slower steps carry on while the form is open:
/// 3. If the page has no structured product data and we're still thin,
///    ask LinkPresentation for a title and image.
/// 4. Still missing brand, model or price: the on-device Foundation Model
///    reads the page text.
/// 5. Still missing key specs: the same model looks for just those.
@MainActor
enum ExtractionPipeline {
    struct Reading {
        var draft: ListingDraft
        var snapshot: PageSnapshot?

        var needsLinkPreview: Bool {
            !(snapshot?.hasStructuredData ?? false) && draft.isThin && draft.sourceURL != nil
        }
    }

    static func read(snapshot given: PageSnapshot?, url: URL?, host: UIView?) async -> Reading {
        var snapshot = given
        if snapshot == nil, let url {
            let reader = WebPageReader()
            snapshot = await reader.snapshot(of: url, attachedTo: host)
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
        return Reading(draft: draft, snapshot: snapshot)
    }

    /// Runs the slower steps, publishing the draft after each one that may
    /// have found something.
    static func enrich(_ reading: Reading, preview: LinkPreviewFallback.Preview?, publish: (ListingDraft) -> Void) async {
        guard !Task.isCancelled else { return }
        var draft = reading.draft
        let snapshot = reading.snapshot
        let structured = snapshot?.hasStructuredData ?? false

        if let preview {
            draft.sources.insert(.linkPresentation)
            if let title = preview.title { ListingInterpreter.applyTitle(title, to: &draft) }
            publish(draft)
        }
        // On-device model over the page text, for pages the structure missed.
        if let text = snapshot?.text, text.count > 80,
           draft.brand.isEmpty || draft.model.isEmpty || (!structured && draft.price == nil) {
            await FoundationModelsFallback.fill(&draft, title: snapshot?.title ?? draft.pageTitle, text: text)
            guard !Task.isCancelled else { return }
            publish(draft)
        }

        // Specs the page reading couldn't place, such as ones written as prose.
        let specText = ((snapshot?.specLines ?? []) + [draft.summary, snapshot?.text ?? ""]).joined(separator: "\n")
        if specText.count > 80, SpecNormalizer.essentials.contains(where: { label in !draft.specs.contains { $0.label == label } }) {
            await FoundationModelsFallback.fillSpecs(&draft, text: specText)
            guard !Task.isCancelled else { return }
            publish(draft)
        }
    }
}
