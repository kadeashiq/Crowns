import SwiftUI

/// Hierarchy is drop shadows: the more something matters, the higher it sits.
/// Each level is a tight shadow for the edge and a wide one for the lift.
enum Elevation {
    /// On the page. Pressed cards.
    case flat
    /// Cards and resting controls.
    case low
    /// Selected controls and bars.
    case mid
    /// The add button, a watch in its sheet.
    case high

    fileprivate struct Layer {
        let opacity: Double
        let radius: CGFloat
        let y: CGFloat
    }

    fileprivate var layers: (edge: Layer, lift: Layer) {
        switch self {
        case .flat:
            (Layer(opacity: 0, radius: 0, y: 0), Layer(opacity: 0, radius: 0, y: 0))
        case .low:
            (Layer(opacity: 0.05, radius: 2, y: 1), Layer(opacity: 0.07, radius: 14, y: 6))
        case .mid:
            (Layer(opacity: 0.07, radius: 3, y: 2), Layer(opacity: 0.12, radius: 22, y: 10))
        case .high:
            (Layer(opacity: 0.10, radius: 6, y: 3), Layer(opacity: 0.20, radius: 36, y: 18))
        }
    }
}

private struct ElevationModifier: ViewModifier {
    let level: Elevation
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let layers = level.layers
        // Shadows barely show against black, so dark mode casts them harder.
        let strength = scheme == .dark ? 2.2 : 1.0
        content
            .shadow(color: .black.opacity(min(layers.edge.opacity * strength, 1)), radius: layers.edge.radius, y: layers.edge.y)
            .shadow(color: .black.opacity(min(layers.lift.opacity * strength, 1)), radius: layers.lift.radius, y: layers.lift.y)
    }
}

extension View {
    func elevation(_ level: Elevation) -> some View {
        modifier(ElevationModifier(level: level))
    }

    /// A filled, rounded background. The shadow belongs to the shape, so text
    /// on top stays crisp.
    func surface(_ fill: Color = Theme.surface, radius: CGFloat = Radius.lg, elevation level: Elevation = .low) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
                .elevation(level)
        }
    }
}
