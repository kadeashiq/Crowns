import Foundation
import SwiftData
import SwiftUI
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
    private func filledBox(_ context: ModelContext, count: Int) -> (Box, [Watch]) {
        let box = Box(name: "Test", columns: 2, rows: 2)
        context.insert(box)
        let watches = (0..<count).map { index -> Watch in
            let watch = Watch()
            context.insert(watch)
            watch.box = box
            watch.slot = index
            return watch
        }
        return (box, watches)
    }

    @Test func gridsAddColumnsAsTheWindowWidens() {
        #expect(GridMetrics.columns(forWidth: 0, preferred: 2) == 2)
        #expect(GridMetrics.columns(forWidth: 402, preferred: 2) == 2)
        #expect(GridMetrics.columns(forWidth: 466, preferred: 2) == 2)
        #expect(GridMetrics.columns(forWidth: 834, preferred: 2) == 4)
        #expect(GridMetrics.columns(forWidth: 1194, preferred: 2) == 5)
        #expect(GridMetrics.columns(forWidth: 440, preferred: 4) == 4)
        #expect(GridMetrics.columns(forWidth: 834, preferred: 1) == 2)
    }

    @Test func onlyALargeLandscapeWindowNarrowsItsContent() {
        #expect(Layout.contentWidth(in: CGSize(width: 402, height: 874)) == 402)
        #expect(Layout.contentWidth(in: CGSize(width: 834, height: 1210)) == 834)
        #expect(Layout.contentWidth(in: CGSize(width: 951, height: 669)) == 951)
        #expect(Layout.contentWidth(in: CGSize(width: 1210, height: 834)) == 847)
    }

    private struct Card: Identifiable, Equatable {
        let id: Int
    }

    private func cards(_ ids: Int...) -> [Card] { ids.map(Card.init) }

    @Test func aDroppedCardLandsBeforeItsAnchor() {
        #expect(cards(0, 1, 2, 3).placing([3], before: 1) == cards(0, 3, 1, 2))
        #expect(cards(0, 1, 2, 3).placing([0], before: 2) == cards(1, 0, 2, 3))
        #expect(cards(0, 1, 2, 3).placing([1], before: 0) == cards(1, 0, 2, 3))
    }

    @Test func aCardDroppedWithNoAnchorGoesLast() {
        #expect(cards(0, 1, 2).placing([0], before: nil) == cards(1, 2, 0))
        #expect(cards(0, 1, 2).placing([2], before: nil) == cards(0, 1, 2))
    }

    @Test func cardsDroppedTogetherKeepTheOrderTheyWerePickedIn() {
        #expect(cards(0, 1, 2, 3).placing([3, 2], before: 0) == cards(3, 2, 0, 1))
        #expect(cards(0, 1, 2, 3).placing([0, 2], before: nil) == cards(1, 3, 0, 2))
    }

    @Test func aDropNeverLosesOrRepeatsACard() {
        // The anchor is one of the cards picked up.
        #expect(cards(0, 1, 2, 3).placing([1, 2], before: 2) == cards(0, 1, 2, 3))
        #expect(cards(0, 1, 2, 3).placing([3, 1], before: 1) == cards(0, 3, 1, 2))
        // Cards and anchors the grid has never seen.
        #expect(cards(0, 1, 2).placing([9, 1, 1], before: 0) == cards(1, 0, 2))
        #expect(cards(0, 1, 2).placing([0], before: 9) == cards(1, 2, 0))
        #expect(cards().placing([4], before: nil) == cards())
    }

    @Test func seatingWritesOnlyTheSlotsThatChange() throws {
        let context = try memoryContext()
        let (box, w) = filledBox(context, count: 4)
        try context.save()

        box.seat([w[0], w[1], w[2], w[3]])
        #expect(!context.hasChanges)

        box.seat([w[0], w[2], w[1], w[3]])
        #expect(box.sortedWatches.map(\.id) == [w[0], w[2], w[1], w[3]].map(\.id))
        #expect(box.sortedWatches.map(\.slot) == [0, 1, 2, 3])
        #expect(Set(context.changedModelsArray.map(\.persistentModelID)) == [w[1].persistentModelID, w[2].persistentModelID])
    }

    @Test func seatingClosesGapsAndGrowsTheBox() throws {
        let (box, w) = filledBox(try memoryContext(), count: 5)
        w[4].slot = 9
        box.rows = 1
        box.seat([w[4], w[0], w[1], w[2], w[3]])
        #expect(box.sortedWatches.map(\.id) == [w[4], w[0], w[1], w[2], w[3]].map(\.id))
        #expect(box.sortedWatches.map(\.slot) == [0, 1, 2, 3, 4])
        #expect(box.rows == 3)
    }

    @Test func cardGridFillsRowsFromTheTopLeft() {
        let grid = CardGrid(columns: 2, spacing: 10, aspectRatio: 0.5)
        #expect(grid.frame(at: 0, inWidth: 210) == CGRect(x: 0, y: 0, width: 100, height: 200))
        #expect(grid.frame(at: 1, inWidth: 210) == CGRect(x: 110, y: 0, width: 100, height: 200))
        #expect(grid.frame(at: 4, inWidth: 210) == CGRect(x: 0, y: 420, width: 100, height: 200))
        // A grid asked for no columns still lays out one.
        #expect(CardGrid(columns: 0, spacing: 10, aspectRatio: 1).frame(at: 2, inWidth: 80) == CGRect(x: 0, y: 180, width: 80, height: 80))
    }

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
        let watch = try WatchRecorder.save(draft, to: box, in: context)
        #expect(watch.pricePence == 331_200)
        #expect(watch.priceNote == "$4,250 converted")
        #expect(watch.originalCurrency == "USD")
        #expect(watch.priceLabel == "£3,312")
    }

    @Test func savingMakesTheCoverFromTheChosenPhotoAlone() async throws {
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
        let expected = await CoverImages.encoding(photos[1].data)
        #expect(saved.coverData == expected.cover)
        #expect(saved.thumbnailData == expected.thumbnail)
        #expect(saved.hasCover)
        #expect(saved.sortedPhotos.isEmpty)
        #expect(closed)
    }

    @Test func compactingWritesOnlyTheSlotsThatChange() throws {
        let context = try memoryContext()
        let box = Box(name: "Test", columns: 2, rows: 2)
        context.insert(box)
        let first = Watch()
        let second = Watch()
        first.box = box
        second.box = box
        first.slot = 0
        second.slot = 3
        try context.save()

        box.compactSlots()

        #expect(first.slot == 0)
        #expect(second.slot == 1)
        #expect(context.changedModelsArray.count == 1)
    }

    @Test func valuesThePageWasUnsureOfCanBePickedOrRemoved() throws {
        let context = try memoryContext()
        let model = AddWatchModel(context: context, isExtension: false) { _ in }
        model.specs = [EditableSpec(label: "Calibre", value: "Calibre 868")]
        model.suggested = ["Calibre": ["Calibre 868", "Calibre 925"]]
        #expect(model.options(for: "Calibre") == ["Calibre 868", "Calibre 925"])

        model.pick("Calibre 925", for: "Calibre")
        #expect(model.value(of: "Calibre") == "Calibre 925")

        model.removeOption("Calibre 925", for: "Calibre")
        #expect(model.value(of: "Calibre") == "Calibre 868")
        model.removeOption("Calibre 868", for: "Calibre")
        #expect(model.value(of: "Calibre").isEmpty)
        #expect(!model.hasSuggestions)
    }

    @Test func editingAnUnsureValueMakesItTheUsers() throws {
        let context = try memoryContext()
        let model = AddWatchModel(context: context, isExtension: false) { _ in }
        model.reference = "M79030N"
        model.suggested = ["Reference": ["M79030N"]]
        model.reference = "M79030N-0001"
        #expect(!model.isSuggested("Reference"))
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

@Suite("Image cache", .serialized)
struct ImageCacheTests {
    private func picture() -> ImageBytes {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let jpeg = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100), format: format).jpegData(withCompressionQuality: 0.9) { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        return .data(jpeg)
    }

    /// Each picture costs 40,000 here, so two fit.
    @Test func dropsTheLeastRecentlyUsed() async {
        let cache = ImageCache(costLimit: 80_000)
        _ = await cache.image(for: "a", bytes: picture(), maxPixel: 100)
        _ = await cache.image(for: "b", bytes: picture(), maxPixel: 100)
        #expect(cache.cached("a") != nil)
        _ = await cache.image(for: "c", bytes: picture(), maxPixel: 100)
        #expect(cache.cached("a") != nil)
        #expect(cache.cached("b") == nil)
        #expect(cache.cached("c") != nil)
    }

    @Test func keepsImagesWhenTheAppGoesToTheBackground() async {
        let cache = ImageCache()
        _ = await cache.image(for: "a", bytes: picture(), maxPixel: 100)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        #expect(cache.cached("a") != nil)
    }

    @Test func letsGoWhenMemoryRunsShort() async {
        let cache = ImageCache()
        _ = await cache.image(for: "a", bytes: picture(), maxPixel: 100)
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        #expect(cache.cached("a") == nil)
    }
}
