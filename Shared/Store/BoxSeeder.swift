import Foundation
import SwiftData

/// Creates Collection and Wishlist on first run, and merges the duplicates
/// that appear when two devices each seeded before CloudKit caught up.
@MainActor
enum BoxSeeder {
    static let collectionKey = "collection"
    static let wishlistKey = "wishlist"

    static func ensureDefaults(in context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Box>())) ?? 0
        if count == 0 {
            context.insert(Box(name: "Collection", columns: 2, rows: 3, finish: .walnut, sortIndex: 0, seedKey: collectionKey))
            context.insert(Box(name: "Wishlist", columns: 2, rows: 3, finish: .ebony, sortIndex: 1, seedKey: wishlistKey))
            try? context.save()
        }
        mergeDuplicateSeeds(in: context)
    }

    static func mergeDuplicateSeeds(in context: ModelContext) {
        guard let boxes = try? context.fetch(FetchDescriptor<Box>()) else { return }
        var changed = false
        let seeded = Dictionary(grouping: boxes.filter { $0.seedKey != nil }) { $0.seedKey ?? "" }
        for (_, copies) in seeded where copies.count > 1 {
            let ordered = copies.sorted { $0.createdAt < $1.createdAt }
            let keeper = ordered[0]
            for duplicate in ordered.dropFirst() {
                for watch in duplicate.sortedWatches {
                    let slot = keeper.claimFreeSlot()
                    watch.box = keeper
                    watch.slot = slot
                }
                context.delete(duplicate)
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    static func orderedBoxes(in context: ModelContext) -> [Box] {
        let descriptor = FetchDescriptor<Box>(sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
