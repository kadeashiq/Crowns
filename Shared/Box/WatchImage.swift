import SwiftUI

/// A watch's photo, cropped to fill whatever frame it's given.
struct WatchImage: View {
    enum Size {
        case thumbnail, card, full

        /// Each size is decoded once and cached, so opening a watch is instant.
        var maxPixel: Int {
            switch self {
            case .thumbnail: 240
            case .card: 800
            case .full: 1400
            }
        }
    }

    let watch: Watch
    var size: Size = .card
    /// The pixels the frame needs along its longer side, when that is fewer
    /// than the size's own. A small card then decodes a small image.
    var pixels: Int?

    var body: some View {
        Theme.well
            .overlay {
                DecodedImage(
                    key: size == .thumbnail ? watch.thumbnailKey : watch.coverKey,
                    bytes: size == .thumbnail ? .data(watch.thumbnailData) : .cover(of: watch),
                    maxPixel: min(pixels ?? size.maxPixel, size.maxPixel),
                    contentMode: .fill
                )
            }
            .overlay {
                if !watch.hasCover {
                    Image(systemName: "watch.analog")
                        .font(.title)
                        .foregroundStyle(Theme.inkTertiary)
                        .accessibilityHidden(true)
                }
            }
            .clipped()
    }
}
