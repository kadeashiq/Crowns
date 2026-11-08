import SwiftUI
import CoreGraphics

/// Deterministic randomness, so each box keeps the same grain forever.
struct SeededRandom {
    private var state: UInt64

    init(_ seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    init(uuid: UUID) {
        let u = uuid.uuid
        let a = UInt64(u.0) | UInt64(u.1) << 8 | UInt64(u.2) << 16 | UInt64(u.3) << 24
        let b = UInt64(u.4) << 32 | UInt64(u.5) << 40 | UInt64(u.6) << 48 | UInt64(u.7) << 56
        self.init(a | b)
    }

    /// SplitMix64.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }

    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * unit() }
}

/// Wood grain drawn once per box: long, slightly wavering strokes with the
/// odd tighter figure, in the finish's light and dark grain colours.
struct WoodGrain: View {
    let palette: FinishPalette
    let seed: UUID

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            var rng = SeededRandom(uuid: seed)
            let count = max(Int(size.height / 2.6), 12)
            for i in 0..<count {
                let baseY = Double(i) / Double(count) * size.height + rng.range(-1.5, 1.5)
                let amplitude = rng.range(0.4, 3.2)
                let frequency = rng.range(0.003, 0.011)
                let phase = rng.range(0, .pi * 2)
                let drift = rng.range(-0.012, 0.012)
                var path = Path()
                var x = -8.0
                path.move(to: CGPoint(x: x, y: baseY))
                while x <= size.width + 8 {
                    x += 6
                    let y = baseY + sin(x * frequency + phase) * amplitude + sin(x * frequency * 3.1 + phase * 0.5) * amplitude * 0.25 + x * drift
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                let light = rng.unit() < 0.45
                let alpha = rng.range(0.05, 0.24) * palette.grainStrength
                context.stroke(path, with: .color((light ? palette.grainLight : palette.grainDark).opacity(alpha)), lineWidth: rng.range(0.35, 1.7))
            }
            // A couple of cathedral arches: the figure you see on cut planks.
            for _ in 0..<2 {
                let cx = rng.range(0.15, 0.85) * size.width
                let cy = rng.range(0.1, 0.9) * size.height
                for ring in 0..<7 {
                    let rx = 18.0 + Double(ring) * rng.range(5, 9)
                    let ry = rx * rng.range(0.16, 0.24)
                    let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
                    context.stroke(Path(ellipseIn: rect), with: .color(palette.grainDark.opacity(0.10 * palette.grainStrength)), lineWidth: 0.7)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Fine, low-contrast noise tiled over suede so it reads as nap, not plastic.
enum SuedeTexture {
    static let image: Image = {
        let side = 128
        var rng = SeededRandom(42)
        var pixels = [UInt8](repeating: 128, count: side * side)
        for i in pixels.indices {
            // Mostly fine noise, with short horizontal fibres.
            let n = Int(rng.next() % 64) - 32
            let fibre = (i % side) % 7 == 0 ? Int(rng.next() % 18) - 9 : 0
            pixels[i] = UInt8(clamping: 128 + n + fibre)
        }
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data),
              let cg = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: side,
                               space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            return Image(systemName: "circle.fill")
        }
        return Image(decorative: cg, scale: 2)
    }()
}
