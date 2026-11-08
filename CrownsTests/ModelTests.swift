import Foundation
import SwiftData
import Testing
import UIKit

@MainActor
private func memoryContext() throws -> ModelContext {
    let config = ModelConfiguration(schema: SharedStore.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: SharedStore.schema, configurations: config)
    return ModelContext(container)
}

@Suite("Boxes and watches")
@MainActor
struct ModelTests {
    @Test func fullBoxGrowsARow() throws {
        let context = try memoryContext()
        let box = Box(name: "Test", columns: 2, rows: 1)
        context.insert(box)
        for _ in 0..<2 {
            let watch = Watch()
            context.insert(watch)
            let slot = box.claimFreeSlot()
            watch.box = box
            watch.slot = slot
        }
        #expect(box.rows == 1)
        #expect(box.claimFreeSlot() == 2)
        #expect(box.rows == 2)
    }

    @Test func compactingRenumbersAndGrows() throws {
        let context = try memoryContext()
        let box = Box(name: "Test", columns: 2, rows: 3)
        context.insert(box)
        for slot in [5, 1, 3] {
            let watch = Watch()
            context.insert(watch)
            watch.box = box
            watch.slot = slot
        }
        box.columns = 1
        box.rows = 1
        box.compactSlots()
        #expect(box.sortedWatches.map(\.slot) == [0, 1, 2])
        #expect(box.capacity >= 3)
    }

    @Test func duplicateSeedBoxesMerge() throws {
        let context = try memoryContext()
        BoxSeeder.ensureDefaults(in: context)
        // A second device's copy of Wishlist arrives through sync, with a watch on it.
        let copy = Box(name: "Wishlist", sortIndex: 1, seedKey: BoxSeeder.wishlistKey)
        copy.createdAt = Date().addingTimeInterval(60)
        context.insert(copy)
        let watch = Watch()
        context.insert(watch)
        watch.box = copy
        try context.save()

        BoxSeeder.mergeDuplicateSeeds(in: context)
        let boxes = try context.fetch(FetchDescriptor<Box>())
        #expect(boxes.count == 2)
        #expect(watch.box?.seedKey == BoxSeeder.wishlistKey)
        #expect(watch.box?.id != copy.id)
    }

    @Test func recorderKeepsConversionNote() throws {
        let context = try memoryContext()
        let box = Box(name: "Test")
        context.insert(box)
        var draft = ListingDraft()
        draft.brand = "Omega"
        draft.price = Money(amount: 3312, currency: "GBP")
        draft.originalPrice = Money(amount: 4250, currency: "USD")
        let watch = try WatchRecorder.save(draft, photos: [], coverIndex: 0, to: box, in: context)
        #expect(watch.pricePence == 331_200)
        #expect(watch.priceNote == "$4,250 converted")
        #expect(watch.originalCurrency == "USD")
        #expect(watch.priceLabel == "£3,312")
    }

    @Test func savingImportsOnlyTheChosenPhoto() async throws {
        let context = try memoryContext()
        var closed = false
        let model = AddWatchModel(context: context, isExtension: false) { _ in closed = true }
        let photos = try [UIColor.red, .green, .blue].map { color in
            let jpeg = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 600)).jpegData(withCompressionQuality: 0.9) { ctx in
                color.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
            }
            return try #require(ImageFetcher.photo(from: jpeg))
        }
        model.photos = photos
        model.visiblePhotoID = photos[1].id
        model.stage = .ready

        await model.save()

        let saved = try #require(try context.fetch(FetchDescriptor<Watch>()).first)
        #expect(saved.sortedPhotos.map(\.data) == [photos[1].data])
        #expect(closed)
    }

    @Test func savingKeepsWhatWasTyped() async throws {
        let context = try memoryContext()
        let model = AddWatchModel(context: context, isExtension: true) { _ in }
        model.brand = "Tudor"
        model.model = "Pelagos"
        model.reference = "M25600TN"
        model.priceText = "3,200"
        model.notes = "  Birthday  "
        model.stage = .ready

        await model.save()

        let saved = try #require(try context.fetch(FetchDescriptor<Watch>()).first)
        #expect(saved.brand == "Tudor")
        #expect(saved.model == "Pelagos")
        #expect(saved.reference == "M25600TN")
        #expect(saved.pricePence == 320_000)
        #expect(saved.notes == "Birthday")
    }
}

@Suite("Grid geometry")
struct GridMetricsTests {
    @Test func cellsAreTallerThanWideWhenSideBySide() {
        for columns in 2...4 {
            #expect(GridMetrics(columns: columns).aspectRatio < 1)
        }
    }

    @Test func captionsGoWhenCellsGetNarrow() {
        #expect(GridMetrics(columns: 3).showsCaption)
        #expect(!GridMetrics(columns: 4).showsCaption)
    }

    @Test func sixWatchesFitAPhoneWithoutScrolling() {
        let width = (393 - 16 * 2 - Space.sm) / 2
        let height = width / GridMetrics(columns: 2).aspectRatio
        #expect(height * 3 + Space.sm * 2 < 700)
    }
}

@Suite("Price notes")
struct PriceNoteTests {
    @Test func convertedAndUnconverted() {
        var d = ListingDraft()
        d.price = Money(amount: 1290, currency: "GBP")
        d.originalPrice = Money(amount: 1650, currency: "USD")
        #expect(d.priceNote == "$1,650 converted")

        var offline = ListingDraft()
        offline.price = Money(amount: 2300, currency: "EUR")
        #expect(offline.priceNote == "€2,300")

        var local = ListingDraft()
        local.price = Money(amount: 950, currency: "GBP")
        #expect(local.priceNote == "")
    }
}
