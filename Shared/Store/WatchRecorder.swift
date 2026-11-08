import Foundation
import SwiftData

/// Turns a draft and its photos into a saved Watch.
@MainActor
enum WatchRecorder {
    static let coverPixel = 1000
    static let thumbnailPixel = 240

    @discardableResult
    static func save(_ draft: ListingDraft, photos: [ImageFetcher.Photo], coverIndex: Int, to box: Box, in context: ModelContext) throws -> Watch {
        let watch = Watch()
        watch.brand = draft.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        watch.model = draft.model.trimmingCharacters(in: .whitespacesAndNewlines)
        watch.reference = draft.reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let price = draft.price {
            if price.isGBP {
                watch.pricePence = price.pence
            } else {
                // Conversion to £ arrives with the currency work in phase 4;
                // until then keep the original so nothing is lost.
                watch.originalAmount = NSDecimalNumber(decimal: price.amount).doubleValue
                watch.originalCurrency = price.currency
                watch.priceNote = PriceFormatter.original(price)
            }
        }
        watch.sourceURLString = draft.sourceURL?.absoluteString ?? ""
        watch.sourceSiteName = draft.siteName
        watch.specs = draft.specs

        // The chosen cover leads the photo order.
        var ordered = photos
        if photos.indices.contains(coverIndex) {
            ordered.insert(ordered.remove(at: coverIndex), at: 0)
        }
        if let cover = ordered.first {
            watch.coverData = ImageDownscaler.jpeg(from: cover.data, maxPixel: coverPixel, quality: 0.85)
            watch.thumbnailData = ImageDownscaler.jpeg(from: cover.data, maxPixel: thumbnailPixel, quality: 0.75)
        }

        context.insert(watch)
        let slot = box.claimFreeSlot()
        watch.box = box
        watch.slot = slot
        for (index, photo) in ordered.enumerated() {
            let stored = WatchPhoto(data: photo.data, index: index)
            context.insert(stored)
            stored.watch = watch
        }
        try context.save()
        return watch
    }
}
