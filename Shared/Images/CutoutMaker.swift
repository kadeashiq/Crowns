import Foundation
import CoreImage
import Vision
import UniformTypeIdentifiers

/// Lifts the watch out of a product photo with Vision's foreground instance
/// mask, so it can sit on a cushion. Returns nil whenever the result isn't
/// clearly a cut-out (no subject found, or the "subject" is the whole frame);
/// callers then use the photo as it is.
enum CutoutMaker {
    /// Vision runs on an image no larger than this. Keeps the extension's
    /// memory flat and is plenty for an object the size of a cushion.
    static let workingPixel = 1024

    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func cutout(from data: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) { make(from: data) }.value
    }

    private static func make(from data: Data) -> Data? {
        guard let input = ImageDownscaler.thumbnail(from: data, maxPixel: workingPixel) else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: input, options: [:])
        do {
            try handler.perform([request])
        } catch {
            // Unsupported on this device (e.g. the Simulator) or failed: use the photo.
            return nil
        }
        guard let result = request.results?.first, !result.allInstances.isEmpty,
              let buffer = try? result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: true) else {
            return nil
        }
        let image = CIImage(cvPixelBuffer: buffer)
        let fullArea = Double(input.width * input.height)
        let cutArea = Double(image.extent.width * image.extent.height)
        guard fullArea > 0, cutArea / fullArea > 0.02, cutArea / fullArea < 0.995 else { return nil }
        guard let cg = context.createCGImage(image, from: image.extent) else { return nil }
        return ImageDownscaler.encode(cg, type: .png)
    }
}
