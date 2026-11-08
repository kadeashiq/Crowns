import SwiftUI

/// A small engraved brass plate on the front of the box.
struct NamePlate: View {
    let text: String

    private static let brassLight = Color(red: 0.93, green: 0.82, blue: 0.56)
    private static let brass = Color(red: 0.76, green: 0.60, blue: 0.32)
    private static let brassDark = Color(red: 0.48, green: 0.36, blue: 0.16)

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .serif))
            .tracking(2.4)
            .lineLimit(1)
            .foregroundStyle(Color(red: 0.24, green: 0.17, blue: 0.07))
            // Engraving: a light edge below the cut.
            .shadow(color: .white.opacity(0.4), radius: 0, x: 0, y: 0.6)
            .padding(.horizontal, 20)
            .frame(height: 17)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(LinearGradient(colors: [Self.brassLight, Self.brass, Self.brassDark, Self.brass],
                                             startPoint: .top, endPoint: .bottom))
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.0), .white.opacity(0.35), .white.opacity(0.0)],
                                             startPoint: .leading, endPoint: .trailing))
                        .blendMode(.softLight)
                    HStack {
                        screw
                        Spacer()
                        screw
                    }
                    .padding(.horizontal, 5)
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .strokeBorder(Self.brassDark.opacity(0.8), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.55), radius: 1.5, x: 0, y: 1)
            }
            .accessibilityLabel(text)
    }

    private var screw: some View {
        Circle()
            .fill(RadialGradient(colors: [Self.brassLight, Self.brassDark], center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: 2.4))
            .frame(width: 4, height: 4)
            .overlay(Rectangle().fill(Self.brassDark).frame(width: 3, height: 0.6).rotationEffect(.degrees(35)))
    }
}
