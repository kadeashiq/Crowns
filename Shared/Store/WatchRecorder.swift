import Foundation
import SwiftData

/// A photo's cover and thumbnail, encoded ahead of saving so the slow part
/// stays off the main thread.
struct CoverImages: Sendable {
    static let coverPixel = 1400
    static let thumbnailPixel = 240

    var cover: Data?
    var thumbnail: Data?

    static func encoding(_ photo: Data?) async -> CoverImages {
        guard let photo else { return CoverImages() }
        return await Task.detached(priority: .userInitiated) {
            CoverImages(
                cover: ImageDownscaler.jpeg(from: photo, maxPixel: coverPixel, quality: 0.85),
                thumbnail: ImageDownscaler.jpeg(from: photo, maxPixel: thumbnailPixel, quality: 0.75)
            )
        }.value
    }
}

/// Turns a draft and its photo into a saved Watch.
@MainActor
enum WatchRecorder {
    @discardableResult
    static func save(_ draft: ListingDraft, notes: String = "", cover: CoverImages = CoverImages(), to box: Box, in context: ModelContext) throws -> Watch {
        let watch = Watch()
        apply(draft, to: watch)
        watch.notes = notes
        setCover(of: watch, to: cover)

        context.insert(watch)
        let slot = box.claimFreeSlot()
        watch.box = box
        watch.slot = slot
        try context.save()
        return watch
    }

    static func apply(_ draft: ListingDraft, to watch: Watch) {
        watch.brand = draft.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        watch.model = draft.model.trimmingCharacters(in: .whitespacesAndNewlines)
        watch.reference = draft.reference.trimmingCharacters(in: .whitespacesAndNewlines)
        watch.pricePence = draft.price?.pence
        watch.priceNote = draft.priceNote
        let original = draft.originalPrice ?? (draft.price?.isGBP == false ? draft.price : nil)
        watch.originalAmount = original.map { NSDecimalNumber(decimal: $0.amount).doubleValue }
        watch.originalCurrency = original?.currency
        watch.sourceURLString = draft.sourceURL?.absoluteString ?? ""
        watch.sourceSiteName = draft.siteName
        watch.specs = draft.specs
    }

    /// Sets the cover and thumbnail.
    static func setCover(of watch: Watch, to images: CoverImages) {
        watch.coverIsCutout = false
        watch.coverData = images.cover
        watch.thumbnailData = images.thumbnail
    }
}
