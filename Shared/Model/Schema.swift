import Foundation
import SwiftData

// CloudKit-compatible SwiftData schema.
//
// CloudKit rules this follows: every attribute has a default or is optional,
// relationships are optional, and nothing is marked unique. Images use
// external storage so they sync as CKAssets rather than bloating records.
//
// Once this schema is deployed to the CloudKit production environment,
// fields can only be added, never removed or retyped. Add a V2 rather than
// editing V1 after launch.

enum CrownsSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Box.self, Watch.self, WatchPhoto.self]
    }

    @Model
    final class Box {
        var id: UUID = UUID()
        var name: String = ""
        var columns: Int = 2
        var rows: Int = 3
        var finishRaw: String = BoxFinish.walnut.rawValue
        var sortIndex: Int = 0
        var createdAt: Date = Date()
        /// Set on the boxes Crowns creates itself ("collection", "wishlist") so
        /// copies seeded on two devices can be merged after CloudKit syncs.
        var seedKey: String?

        @Relationship(deleteRule: .nullify, inverse: \Watch.box)
        var watches: [Watch]? = []

        init(name: String, columns: Int = 2, rows: Int = 3, finish: BoxFinish = .walnut, sortIndex: Int = 0, seedKey: String? = nil) {
            self.id = UUID()
            self.name = name
            self.columns = columns
            self.rows = rows
            self.finishRaw = finish.rawValue
            self.sortIndex = sortIndex
            self.createdAt = Date()
            self.seedKey = seedKey
        }
    }

    @Model
    final class Watch {
        var id: UUID = UUID()
        var brand: String = ""
        var model: String = ""
        var reference: String = ""

        /// Price in pence. Prices are always pounds; foreign listings are converted.
        var pricePence: Int?
        /// Shown under the price, e.g. "$1,650 converted".
        var priceNote: String = ""
        var originalAmount: Double?
        var originalCurrency: String?

        var notes: String = ""
        var sourceURLString: String = ""
        var sourceSiteName: String = ""
        /// Encoded [Spec]. Stored as data rather than a Codable array to keep
        /// the CloudKit mapping simple and predictable.
        var specsData: Data?

        /// Position in the box grid, row-major from the top left.
        var slot: Int = 0
        var addedAt: Date = Date()

        /// The chosen photo, downscaled. `coverIsCutout` is only true on older
        /// saves, from when covers were cut out of their photos.
        @Attribute(.externalStorage) var coverData: Data?
        var coverIsCutout: Bool = false
        /// Small JPEG for list rows, so lists never decode full images.
        @Attribute(.externalStorage) var thumbnailData: Data?

        var box: Box?

        @Relationship(deleteRule: .cascade, inverse: \WatchPhoto.watch)
        var photos: [WatchPhoto]? = []

        init() {
            self.id = UUID()
            self.addedAt = Date()
        }
    }

    @Model
    final class WatchPhoto {
        var id: UUID = UUID()
        var index: Int = 0
        @Attribute(.externalStorage) var data: Data?
        var watch: Watch?

        init(data: Data, index: Int) {
            self.id = UUID()
            self.data = data
            self.index = index
        }
    }
}

typealias Box = CrownsSchemaV1.Box
typealias Watch = CrownsSchemaV1.Watch
typealias WatchPhoto = CrownsSchemaV1.WatchPhoto

enum CrownsMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [CrownsSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

// MARK: - Conveniences

extension CrownsSchemaV1.Box {
    var finish: BoxFinish {
        get { BoxFinish(rawValue: finishRaw) ?? .walnut }
        set { finishRaw = newValue.rawValue }
    }

    var capacity: Int { max(columns, 1) * max(rows, 1) }

    var sortedWatches: [Watch] {
        (watches ?? []).sorted { ($0.slot, $0.addedAt) < ($1.slot, $1.addedAt) }
    }

    func isFree(_ slot: Int) -> Bool {
        slot >= 0 && slot < capacity && !(watches ?? []).contains { $0.slot == slot }
    }

    /// Renumbers slots 0, 1, 2… in their current order, growing the box if
    /// it is now too small. Used after the grid size changes.
    func compactSlots() {
        let ordered = sortedWatches
        while capacity < ordered.count { rows += 1 }
        for (index, watch) in ordered.enumerated() { watch.slot = index }
    }

    /// Seats these watches in slots 0, 1, 2… in the order given, adding rows
    /// if the box is too small. Only a watch whose slot changes is written,
    /// so moving one card doesn't mark the whole box for syncing.
    func seat(_ ordered: [Watch]) {
        let rowsNeeded = (ordered.count + max(columns, 1) - 1) / max(columns, 1)
        if rows < rowsNeeded { rows = rowsNeeded }
        for (slot, watch) in ordered.enumerated() where watch.slot != slot {
            watch.slot = slot
        }
    }

    /// The first free slot. A full box grows by one row rather than
    /// refusing the save, so saving from Safari never dead-ends.
    func claimFreeSlot() -> Int {
        let taken = Set((watches ?? []).map(\.slot))
        if let free = (0..<capacity).first(where: { !taken.contains($0) }) {
            return free
        }
        let next = capacity
        rows += 1
        return next
    }
}

extension CrownsSchemaV1.Watch {
    var specs: [Spec] {
        get {
            guard let specsData else { return [] }
            return (try? JSONDecoder().decode([Spec].self, from: specsData)) ?? []
        }
        set {
            specsData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue)
        }
    }

    var sourceURL: URL? { URL(string: sourceURLString) }

    var sortedPhotos: [WatchPhoto] {
        (photos ?? []).sorted { $0.index < $1.index }
    }

    /// "Rolex Submariner Date", falling back to whatever we have.
    var displayName: String {
        let parts = [brand, model].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return parts.isEmpty ? "Untitled watch" : parts.joined(separator: " ")
    }
}

extension CrownsSchemaV1.Watch {
    /// "£12,950", or the listing's own price if it couldn't be converted.
    var priceLabel: String {
        if let pricePence { return PriceFormatter.pounds(pence: pricePence) }
        return priceNote
    }
}
