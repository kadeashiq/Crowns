import Foundation

/// A watch the share extension couldn't save because the free limit was
/// reached and the purchase couldn't complete inside the extension. The app
/// picks it up next time it opens, shows the paywall, and saves it.
struct PendingSave: Codable {
    var draft: ListingDraft
    var boxID: UUID?
    var coverIndex: Int
    var photoCount: Int
    var hasCutout: Bool
    var date = Date()
}

enum PendingSaveStore {
    private static var directory: URL? {
        AppGroup.containerURL?.appending(path: "Pending", directoryHint: .isDirectory)
    }

    static func stash(_ draft: ListingDraft, photos: [Data], coverIndex: Int, cutout: Data?, boxID: UUID?) {
        guard let dir = directory else { return }
        clear()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (i, photo) in photos.enumerated() {
            try? photo.write(to: dir.appending(path: "photo-\(i).jpg"), options: .atomic)
        }
        if let cutout { try? cutout.write(to: dir.appending(path: "cutout.png"), options: .atomic) }
        let pending = PendingSave(draft: draft, boxID: boxID, coverIndex: coverIndex, photoCount: photos.count, hasCutout: cutout != nil)
        if let data = try? JSONEncoder().encode(pending) {
            try? data.write(to: dir.appending(path: "pending.json"), options: .atomic)
        }
    }

    static func load() -> (pending: PendingSave, photos: [Data], cutout: Data?)? {
        guard let dir = directory,
              let data = try? Data(contentsOf: dir.appending(path: "pending.json")),
              let pending = try? JSONDecoder().decode(PendingSave.self, from: data) else { return nil }
        // A stale handoff is more confusing than useful.
        guard Date().timeIntervalSince(pending.date) < 7 * 24 * 3600 else {
            clear()
            return nil
        }
        let photos = (0..<pending.photoCount).compactMap { try? Data(contentsOf: dir.appending(path: "photo-\($0).jpg")) }
        let cutout: Data? = pending.hasCutout ? (try? Data(contentsOf: dir.appending(path: "cutout.png"))) : nil
        return (pending, photos, cutout)
    }

    static func clear() {
        guard let dir = directory else { return }
        try? FileManager.default.removeItem(at: dir)
    }
}
