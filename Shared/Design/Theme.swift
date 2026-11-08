import SwiftUI
import UIKit

/// Dark and quiet: an object on a desk at night.
enum Theme {
    static let desk = Color(red: 0.055, green: 0.047, blue: 0.043)
    static let deskLift = Color(red: 0.10, green: 0.085, blue: 0.075)
    static let ink = Color(red: 0.93, green: 0.90, blue: 0.85)
    static let inkSecondary = Color(red: 0.62, green: 0.58, blue: 0.53)
    static let inkTertiary = Color(red: 0.42, green: 0.39, blue: 0.36)
    static let brass = Color(red: 0.79, green: 0.64, blue: 0.36)
    static let hairline = Color.white.opacity(0.08)

    /// The desk the box sits on: a soft pool of lamp light, falling off to black.
    static var deskBackground: some View {
        ZStack {
            desk
            RadialGradient(colors: [deskLift, desk.opacity(0)], center: UnitPoint(x: 0.5, y: 0.35), startRadius: 20, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

/// Materials for each box finish: the wood of the frame and the suede inside.
struct FinishPalette {
    var woodLight: Color
    var wood: Color
    var woodDark: Color
    var grainLight: Color
    var grainDark: Color
    var suedeLight: Color
    var suede: Color
    var suedeDark: Color
    /// The floor of the tray, under the cushions.
    var tray: Color
    /// How visible the grain is. Ebony and lacquer show less.
    var grainStrength: Double

    static func `for`(_ finish: BoxFinish) -> FinishPalette {
        switch finish {
        case .walnut:
            FinishPalette(
                woodLight: Color(red: 0.47, green: 0.31, blue: 0.20), wood: Color(red: 0.35, green: 0.22, blue: 0.13), woodDark: Color(red: 0.20, green: 0.12, blue: 0.07),
                grainLight: Color(red: 0.62, green: 0.43, blue: 0.27), grainDark: Color(red: 0.13, green: 0.07, blue: 0.04),
                suedeLight: Color(red: 0.42, green: 0.33, blue: 0.26), suede: Color(red: 0.32, green: 0.25, blue: 0.19), suedeDark: Color(red: 0.19, green: 0.14, blue: 0.11),
                tray: Color(red: 0.14, green: 0.10, blue: 0.08), grainStrength: 1.0)
        case .ebony:
            FinishPalette(
                woodLight: Color(red: 0.20, green: 0.17, blue: 0.15), wood: Color(red: 0.12, green: 0.10, blue: 0.09), woodDark: Color(red: 0.06, green: 0.05, blue: 0.045),
                grainLight: Color(red: 0.30, green: 0.25, blue: 0.21), grainDark: Color(red: 0.02, green: 0.02, blue: 0.02),
                suedeLight: Color(red: 0.25, green: 0.24, blue: 0.23), suede: Color(red: 0.18, green: 0.17, blue: 0.165), suedeDark: Color(red: 0.10, green: 0.095, blue: 0.09),
                tray: Color(red: 0.07, green: 0.065, blue: 0.06), grainStrength: 0.6)
        case .oak:
            FinishPalette(
                woodLight: Color(red: 0.70, green: 0.55, blue: 0.37), wood: Color(red: 0.58, green: 0.44, blue: 0.28), woodDark: Color(red: 0.40, green: 0.29, blue: 0.17),
                grainLight: Color(red: 0.80, green: 0.66, blue: 0.47), grainDark: Color(red: 0.32, green: 0.22, blue: 0.12),
                suedeLight: Color(red: 0.20, green: 0.25, blue: 0.34), suede: Color(red: 0.14, green: 0.18, blue: 0.26), suedeDark: Color(red: 0.08, green: 0.10, blue: 0.15),
                tray: Color(red: 0.07, green: 0.09, blue: 0.13), grainStrength: 1.1)
        case .oxblood:
            FinishPalette(
                woodLight: Color(red: 0.46, green: 0.17, blue: 0.16), wood: Color(red: 0.33, green: 0.11, blue: 0.11), woodDark: Color(red: 0.18, green: 0.05, blue: 0.05),
                grainLight: Color(red: 0.55, green: 0.24, blue: 0.22), grainDark: Color(red: 0.10, green: 0.02, blue: 0.02),
                suedeLight: Color(red: 0.27, green: 0.25, blue: 0.24), suede: Color(red: 0.20, green: 0.185, blue: 0.18), suedeDark: Color(red: 0.11, green: 0.10, blue: 0.10),
                tray: Color(red: 0.09, green: 0.075, blue: 0.07), grainStrength: 0.5)
        }
    }
}

/// Every motion is a soft spring that eases in and out. Nothing linear.
enum Motion {
    static let standard = Animation.spring(duration: 0.45, bounce: 0.1)
    static let lift = Animation.spring(duration: 0.55, bounce: 0.14)
    static let settle = Animation.spring(duration: 0.5, bounce: 0.08)
    static let fade = Animation.easeInOut(duration: 0.28)
    static let boxSwitch = Animation.spring(duration: 0.42, bounce: 0.0)
}

@MainActor
enum Haptics {
    /// A watch lifting off its cushion.
    static func lift() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
    }

    /// A watch settling back down. Firmer than the lift.
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
