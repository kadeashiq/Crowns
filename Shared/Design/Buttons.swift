import SwiftUI

/// The main button: a capsule that sinks onto the page when pressed.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet }
    enum Size { case large, small }

    var kind: Kind = .primary
    var size: Size = .large

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
            }
            .contentShape(.capsule)
            .scaleEffect(pressed ? 0.97 : 1)
            .opacity(isEnabled ? (kind == .quiet && pressed ? 0.5 : 1) : 0.4)
            .animation(Motion.press, value: pressed)
    }

    private var fill: Color { kind == .primary ? Theme.ink : Theme.surface }
    private var foreground: Color { kind == .primary ? Theme.onInk : Theme.ink }
    private var rest: Elevation { kind == .primary ? .mid : .low }
}

/// Round icon buttons: close, settings, add.
struct CircleButtonStyle: ButtonStyle {
    enum Kind { case primary, surface, flat }

    var kind: Kind = .surface
    var diameter: CGFloat = 44

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: diameter * 0.36, weight: .semibold))
            .foregroundStyle(kind == .primary ? Theme.onInk : Theme.ink)
            .frame(width: diameter, height: diameter)
            .background {
                if kind == .flat {
                    Circle().fill(Theme.well)
                } else {
                    Circle()
                        .fill(kind == .primary ? Theme.ink : Theme.surface)
                        .elevation(pressed || !isEnabled ? .flat : rest)
                }
            }
            .contentShape(.circle)
            .scaleEffect(pressed ? 0.9 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(Motion.press, value: pressed)
    }

    private var rest: Elevation { kind == .primary ? .high : .low }
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
    static func pill(_ kind: PillButtonStyle.Kind = .primary, size: PillButtonStyle.Size = .large) -> PillButtonStyle {
        PillButtonStyle(kind: kind, size: size)
    }
}

extension ButtonStyle where Self == CircleButtonStyle {
    static func circle(_ kind: CircleButtonStyle.Kind = .surface, diameter: CGFloat = 44) -> CircleButtonStyle {
        CircleButtonStyle(kind: kind, diameter: diameter)
    }
}
