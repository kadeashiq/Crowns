import SwiftUI
import UIKit

/// Black, white and greys. Watches are the only colour on screen.
enum Theme {
    /// The page.
    static let canvas = Color(uiColor: uiCanvas)
    /// Cards, buttons and anything sitting above the page.
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x1C1C1E)
    /// Text fields, and photos while they load.
    static let well = adaptive(light: 0xF2F2F3, dark: 0x2A2A2D)

    static let ink = adaptive(light: 0x0A0A0A, dark: 0xFAFAFA)
    static let inkSecondary = adaptive(light: 0x5E5E63, dark: 0xA8A8AD)
    static let inkTertiary = adaptive(light: 0x77777C, dark: 0x7E7E84)
    /// Text and icons on an `ink` fill.
    static let onInk = adaptive(light: 0xFFFFFF, dark: 0x0A0A0A)
    static let hairline = adaptive(light: 0xE4E4E6, dark: 0x2F2F32)

    /// For UIKit, which can't take SwiftUI colours.
    static let uiCanvas = dynamic(light: 0xF2F2F3, dark: 0x000000)
    static let uiInk = dynamic(light: 0x0A0A0A, dark: 0xFAFAFA)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: dynamic(light: light, dark: dark))
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? rgb(dark) : rgb(light) }
    }

    private static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum Radius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 18
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

/// Text styles, all built on Dynamic Type.
enum Typeface {
    static let display = Font.largeTitle.weight(.bold)
    static let title = Font.title2.weight(.bold)
    static let heading = Font.headline
    static let body = Font.body
    static let button = Font.body.weight(.semibold)
    static let label = Font.subheadline.weight(.semibold)
    static let secondary = Font.subheadline
    static let caption = Font.footnote
    static let micro = Font.caption.weight(.semibold)
    static let price = Font.subheadline.monospacedDigit()
    static let reference = Font.caption.monospaced()
}

/// Touch feedback and selection indicators only. Screens change through
/// native sheets, never custom fades or slides.
enum Motion {
    static let press = Animation.spring(duration: 0.26, bounce: 0.25)
    static let selection = Animation.spring(duration: 0.38, bounce: 0.16)
}

@MainActor
enum Haptics {
    /// A watch opening.
    static func lift() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
    }

    /// A watch leaving a box.
    static func settle() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.9)
    }

    static func saved() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func tick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
