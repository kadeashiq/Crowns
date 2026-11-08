import Foundation
import SwiftData
import Testing

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
        let watch = try WatchRecorder.save(draft, photos: [], coverIndex: 0, coverCutout: nil, to: box, in: context)
        #expect(watch.pricePence == 331_200)
        #expect(watch.priceNote == "$4,250 converted")
        #expect(watch.originalCurrency == "USD")
        #expect(watch.priceLabel == "£3,312")
    }
}

@Suite("Box geometry")
struct BoxMetricsTests {
    @Test func cellsFitTheWidth() {
        let m = BoxMetrics(width: 358, columns: 2, rows: 3)
        let used = m.side * 2 + m.trayPadding * 2 + m.cellWidth * 2 + m.gap
        #expect(abs(used - 358) < 0.001)
        #expect(m.cellHeight > m.cellWidth)
        // Six cushions should fit a phone held in one hand without scrolling.
        #expect(m.height < 700)
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
