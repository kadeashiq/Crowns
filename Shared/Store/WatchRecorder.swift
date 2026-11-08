import Foundation
import SwiftData

/// Turns a draft and its photos into a saved Watch.
@MainActor
enum WatchRecorder {
    static let coverPixel = 1400
    static let thumbnailPixel = 240

    @discardableResult
    static func save(_ draft: ListingDraft, photos: [Data], coverIndex: Int, to box: Box, slot preferred: Int? = nil, in context: ModelContext) throws -> Watch {
        let watch = Watch()
        apply(draft, to: watch)

        // The chosen cover leads the photo order.
        var ordered = photos
        if photos.indices.contains(coverIndex) {
            ordered.insert(ordered.remove(at: coverIndex), at: 0)
        }
        setCover(of: watch, photo: ordered.first)

        context.insert(watch)
        let slot: Int
        if let preferred, box.isFree(preferred) {
            slot = preferred
        } else {
            slot = box.claimFreeSlot()
        }
        watch.box = box
        watch.slot = slot
        for (index, data) in ordered.enumerated() {
            let stored = WatchPhoto(data: data, index: index)
            context.insert(stored)
            stored.watch = watch
        }
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

    /// Sets the cover and thumbnail from the chosen photo.
    static func setCover(of watch: Watch, photo: Data?) {
        watch.coverIsCutout = false
        guard let photo else {
            watch.coverData = nil
            watch.thumbnailData = nil
            return
        }
        watch.coverData = ImageDownscaler.jpeg(from: photo, maxPixel: coverPixel, quality: 0.85)
        watch.thumbnailData = ImageDownscaler.jpeg(from: photo, maxPixel: thumbnailPixel, quality: 0.75)
    }
}
