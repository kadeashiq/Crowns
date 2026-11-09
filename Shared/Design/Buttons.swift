import SwiftUI

/// The main button: a capsule that sinks onto the page when pressed.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet }
    enum Size { case large, small }

    var kind: Kind = .primary
    var size: Size = .large
    /// A light outline, for a white button on a light sheet.
    var bordered = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(size == .large ? Typeface.button : Typeface.label)
            .foregroundStyle(foreground)
            .padding(.horizontal, size == .large ? Space.lg : Space.md)
            .frame(minHeight: size == .large ? 54 : 40)
            .background {
                if kind != .quiet {
                    Capsule().fill(fill).elevation(pressed || !isEnabled ? .flat : rest)
                }
                if bordered {
                    Capsule().strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                }
            }
            .contentShape(.capsule)
            .scaleEffect(pressed ? 0.97 : 1)
            .opacity(kind == .quiet && pressed ? 0.5 : 1)
            .animation(Motion.press, value: pressed)
    }

    // Disabled is solid grey, not faded, because content can scroll beneath.
    private var fill: Color {
        guard isEnabled else { return Theme.hairline }
        return kind == .primary ? Theme.ink : Theme.surface
    }
    private var foreground: Color {
        guard isEnabled else { return Theme.inkTertiary }
        return kind == .primary ? Theme.onInk : Theme.ink
    }
    private var rest: Elevation { kind == .primary ? .mid : .low }
}

/// Round icon buttons: close, settings, add.
struct CircleButtonStyle: ButtonStyle {
    enum Kind { case primary, surface, flat }

    var kind: Kind = .surface
    var diameter: CGFloat = 44

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: diameter * 0.36, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: diameter, height: diameter)
            .contentShape(.circle)
            .glassEffect(glass, in: .circle)
    }

    /// The system's own Liquid Glass, which handles touch feedback itself.
    private var glass: Glass {
        kind == .primary && isEnabled ? .regular.tint(Theme.ink).interactive() : .regular.interactive()
    }

    private var foreground: Color {
        guard isEnabled else { return Theme.inkTertiary }
        return kind == .primary ? Theme.onInk : Theme.ink
    }
}

/// A whole card as a button. The card comes down to the page under the finger.
struct CardButtonStyle: ButtonStyle {
    var radius: CGFloat = Radius.lg

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .surface(radius: radius, elevation: pressed ? .flat : .low)
            .contentShape(.rect(cornerRadius: radius, style: .continuous))
            .scaleEffect(pressed ? 0.96 : 1)
            .animation(Motion.press, value: pressed)
    }
}

/// A small, soft press for anything without a background of its own.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static func pill(_ kind: PillButtonStyle.Kind = .primary, size: PillButtonStyle.Size = .large, bordered: Bool = false) -> PillButtonStyle {
        PillButtonStyle(kind: kind, size: size, bordered: bordered)
    }
}

extension ButtonStyle where Self == CircleButtonStyle {
    static func circle(_ kind: CircleButtonStyle.Kind = .surface, diameter: CGFloat = 44) -> CircleButtonStyle {
        CircleButtonStyle(kind: kind, diameter: diameter)
    }
}
