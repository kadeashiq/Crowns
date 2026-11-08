import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

/// Decodes and resizes with ImageIO thumbnails, which never materialise the
/// full-size bitmap. This is what keeps the share extension under its memory
/// limit with a dozen 4000px product photos.
enum ImageDownscaler {
    static func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: w, height: h)
    }

    /// A CGImage no larger than `maxPixel` on its long side, orientation applied.
    static func thumbnail(from data: Data, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func jpeg(from data: Data, maxPixel: Int, quality: Double = 0.82) -> Data? {
        guard let image = thumbnail(from: data, maxPixel: maxPixel) else { return nil }
        return encode(image, type: .jpeg, quality: quality)
    }

    static func encode(_ image: CGImage, type: UTType, quality: Double = 0.82) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out as CFMutableData, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
