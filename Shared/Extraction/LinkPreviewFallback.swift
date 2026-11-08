import Foundation
import LinkPresentation
import UniformTypeIdentifiers

/// Last structured resort: Apple's link preview fetcher. Gives a title and
/// usually one image, which is enough to save something sensible.
enum LinkPreviewFallback {
    struct Preview {
        var title: String?
        var imageData: Data?
    }

    @MainActor
    static func fetch(_ url: URL) async -> Preview? {
        let provider = LPMetadataProvider()
        provider.timeout = 8
        provider.shouldFetchSubresources = true
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return nil }
        var result = Preview(title: metadata.title)
        if let imageProvider = metadata.imageProvider {
            result.imageData = await loadData(from: imageProvider)
        }
        return result
    }

    private static func loadData(from provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(for: .image) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
