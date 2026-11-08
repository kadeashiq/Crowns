import SwiftUI

/// One suede pillow in its compartment. The watch, if any, sits on top.
struct Compartment<Content: View>: View {
    let palette: FinishPalette
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let inset = max(geo.size.width * 0.045, 5)
            ZStack {
                // The well the cushion sits in.
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(palette.tray.shadow(.inner(color: .black.opacity(0.85), radius: 6, x: 0, y: 3)))
                Cushion(palette: palette)
                    .padding(inset)
                content()
                    .padding(inset)
            }
        }
    }
}

struct Cushion: View {
    let palette: FinishPalette

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let radius = min(w, h) * 0.34
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            ZStack {
                // Domed suede: lit from the upper left, falling into shadow at the edges.
                shape.fill(
                    RadialGradient(colors: [palette.suedeLight, palette.suede, palette.suedeDark],
                                   center: UnitPoint(x: 0.4, y: 0.3), startRadius: 0, endRadius: max(w, h) * 0.78)
                    .shadow(.inner(color: .black.opacity(0.5), radius: radius * 0.45, x: 0, y: -radius * 0.12))
                )
                SuedeTexture.image
                    .resizable(resizingMode: .tile)
                    .blendMode(.overlay)
                    .opacity(0.45)
                    .clipShape(shape)
                // The crease where a strap would wrap round.
                VStack(spacing: 0) {
                    Rectangle().fill(.black.opacity(0.38)).frame(height: 1.4)
                    Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
                }
                .blur(radius: 0.4)
                .clipShape(shape)
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.09), .clear, .black.opacity(0.4)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.6), radius: 5, x: 0, y: 4)
        }
    }
}

enum WatchHeadMetrics {
    /// One decode size for the cushion and the detail view, so the image the
    /// detail needs is already in the cache when a watch lifts.
    static let maxPixel = 1000
}

/// Links a view to its counterpart elsewhere for the lift transition.
struct HeroLink {
    let id: UUID
    let namespace: Namespace.ID
}

private struct HeroModifier: ViewModifier {
    let link: HeroLink?

    func body(content: Content) -> some View {
        if let link {
            content.matchedGeometryEffect(id: link.id, in: link.namespace)
        } else {
            content
        }
    }
}

extension View {
    func hero(_ link: HeroLink?) -> some View {
        modifier(HeroModifier(link: link))
    }
}

/// A watch resting on a cushion: a cut-out sits directly on the suede; a
/// plain photo rests on it like a print, with a small border of shadow.
struct WatchHead: View {
    let key: String
    let data: Data?
    let isCutout: Bool
    var hero: HeroLink? = nil

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Group {
                if isCutout {
                    DecodedImage(key: key, data: data, maxPixel: WatchHeadMetrics.maxPixel)
                        .frame(width: geo.size.width * 0.94, height: geo.size.height * 0.94)
                        .hero(hero)
                        .shadow(color: .black.opacity(0.65), radius: side * 0.05, x: 0, y: side * 0.045)
                } else {
                    DecodedImage(key: key, data: data, maxPixel: WatchHeadMetrics.maxPixel, contentMode: .fill)
                        .frame(width: side * 0.72, height: side * 0.72)
                        .clipShape(RoundedRectangle(cornerRadius: side * 0.08, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: side * 0.08, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
                        .hero(hero)
                        .shadow(color: .black.opacity(0.6), radius: side * 0.04, x: 0, y: side * 0.035)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
