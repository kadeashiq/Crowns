import SwiftData
import SwiftUI
import UIKit

/// Decoded, display-ready images keyed by content. Decoding happens off the
/// main thread before anything is shown, so images never pop in half-drawn.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.totalCostLimit = 120 * 1024 * 1024
    }

    func cached(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func image(for key: String, bytes: ImageBytes, maxPixel: Int) async -> UIImage? {
        if let hit = cached(key) { return hit }
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = bytes.load(), let cg = ImageDownscaler.thumbnail(from: data, maxPixel: maxPixel) else { return nil }
            return UIImage(cgImage: cg, scale: 1, orientation: .up)
        }.value
        if let image {
            cache.setObject(image, forKey: key as NSString, cost: Int(image.size.width * image.size.height * 4))
        }
        return image
    }
}

/// Where an image's bytes come from. A cover or a photo stays in the store
/// until it is decoded, and is read off the main thread by a context of its
/// own, so showing a box never loads full-size photos into the app's context.
struct ImageBytes: Sendable {
    /// Called off the main thread.
    let load: @Sendable () -> Data?

    static func data(_ data: Data?) -> ImageBytes {
        ImageBytes { data }
    }

    /// Reads the saved cover, so a new cover must be saved before it is shown.
    static func cover(of watch: Watch) -> ImageBytes {
        guard let container = watch.modelContext?.container else { return .data(watch.coverData) }
        let id = watch.id
        return ImageBytes {
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<Watch>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            let stored = (try? context.fetch(descriptor))?.first
            return withExtendedLifetime(context) { stored?.coverData }
        }
    }

    static func photo(_ photo: WatchPhoto) -> ImageBytes {
        guard let container = photo.modelContext?.container else { return .data(photo.data) }
        let id = photo.id
        return ImageBytes {
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<WatchPhoto>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            let stored = (try? context.fetch(descriptor))?.first
            return withExtendedLifetime(context) { stored?.data }
        }
    }
}

extension EnvironmentValues {
    /// False on a page that is out of sight. Its images let go of what they
    /// decoded, so the cache is free to drop it when memory runs short.
    @Entry var keepsImages = true
}

/// Shows an image once it is decoded. Holds its frame from the start, so
/// nothing around it moves or resizes when the image arrives.
struct DecodedImage: View {
    let key: String
    let bytes: ImageBytes
    var maxPixel: Int = 1000
    var contentMode: ContentMode = .fit

    @Environment(\.keepsImages) private var keepsImages
    @State private var held: Held?

    private struct Held {
        let key: String
        let image: UIImage?
    }

    static func cacheKey(_ key: String, _ maxPixel: Int) -> String { "\(key)@\(maxPixel)" }

    var body: some View {
        let cacheKey = DecodedImage.cacheKey(key, maxPixel)
        // A cached image shows on the first frame. The detail sheet relies on
        // this to have its image as soon as it opens. When the key changes,
        // the last image stays until the new one is decoded.
        let image = keepsImages ? ImageCache.shared.cached(cacheKey) ?? held?.image : nil
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        }
        .task(id: "\(cacheKey)|\(keepsImages)") {
            guard keepsImages else {
                held = nil
                return
            }
            if let held, held.key == cacheKey, held.image != nil { return }
            let decoded = await ImageCache.shared.image(for: cacheKey, bytes: bytes, maxPixel: maxPixel)
            guard !Task.isCancelled else { return }
            held = Held(key: cacheKey, image: decoded)
        }
    }
}

extension Watch {
    /// True once the watch has a photo. Asks the small thumbnail first, so
    /// laying out a box never loads a cover.
    var hasCover: Bool { thumbnailData != nil || coverData != nil }

    var coverKey: String { "\(id.uuidString)-cover-\(photoStamp)" }
    var thumbnailKey: String { "\(id.uuidString)-thumb-\(photoStamp)" }

    /// Changes whenever the photo does. Taken from the thumbnail, which is
    /// made alongside the cover and is small enough to read while laying out.
    private var photoStamp: String {
        guard let thumbnail = thumbnailData else { return "0" }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in thumbnail.suffix(64) { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
        return "\(thumbnail.count)-\(hash)"
    }
}
