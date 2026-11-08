import SwiftUI

/// Layout numbers for a box drawn at a given width.
struct BoxMetrics {
    let width: CGFloat
    let columns: Int
    let rows: Int

    var side: CGFloat { 15 }
    var top: CGFloat { 15 }
    /// The front edge is deeper: it carries the name plate.
    var front: CGFloat { 30 }
    var trayPadding: CGFloat { 6 }
    var gap: CGFloat { 6 }

    var cellWidth: CGFloat {
        let inner = width - side * 2 - trayPadding * 2 - gap * CGFloat(columns - 1)
        return max(inner / CGFloat(columns), 20)
    }

    /// Slightly taller than wide, like a real watch pillow.
    var cellHeight: CGFloat {
        cellWidth / (columns <= 2 ? 0.8 : columns == 3 ? 0.78 : 0.74)
    }

    var height: CGFloat {
        top + front + trayPadding * 2 + CGFloat(rows) * cellHeight + CGFloat(max(rows - 1, 0)) * gap
    }
}

/// The physical box: a wooden frame, a sunken tray, suede cushions in a grid
/// and a brass name plate. `slot` draws whatever sits on each cushion.
struct WatchBoxView<Slot: View>: View {
    let name: String
    let finish: BoxFinish
    let seed: UUID
    let columns: Int
    let rows: Int
    let width: CGFloat
    @ViewBuilder var slot: (Int) -> Slot

    var body: some View {
        let m = BoxMetrics(width: width, columns: max(columns, 1), rows: max(rows, 1))
        let palette = FinishPalette.for(finish)
        let frame = RoundedRectangle(cornerRadius: 18, style: .continuous)

        ZStack(alignment: .topLeading) {
            // Wood, lacquer and the box's own shadow on the desk.
            frame
                .fill(LinearGradient(colors: [palette.woodLight, palette.wood, palette.woodDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(WoodGrain(palette: palette, seed: seed).clipShape(frame))
                .overlay(
                    frame.fill(LinearGradient(stops: [
                        .init(color: .white.opacity(0.10), location: 0),
                        .init(color: .clear, location: 0.35),
                        .init(color: .black.opacity(0.28), location: 1),
                    ], startPoint: .top, endPoint: .bottom))
                )
                .overlay(frame.strokeBorder(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.02), .black.opacity(0.5)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .shadow(color: .black.opacity(0.75), radius: 26, x: 0, y: 22)
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 3)

            // The sunken tray.
            let tray = RoundedRectangle(cornerRadius: 11, style: .continuous)
            tray
                .fill(palette.tray.shadow(.inner(color: .black.opacity(0.95), radius: 10, x: 0, y: 5)))
                .overlay(tray.strokeBorder(LinearGradient(colors: [.black.opacity(0.7), .white.opacity(0.10)], startPoint: .top, endPoint: .bottom), lineWidth: 1.2))
                .frame(width: m.width - m.side * 2, height: m.height - m.top - m.front)
                .offset(x: m.side, y: m.top)

            // Cushions.
            VStack(spacing: m.gap) {
                ForEach(0..<m.rows, id: \.self) { row in
                    HStack(spacing: m.gap) {
                        ForEach(0..<m.columns, id: \.self) { column in
                            let index = row * m.columns + column
                            Compartment(palette: palette) {
                                slot(index)
                            }
                            .frame(width: m.cellWidth, height: m.cellHeight)
                        }
                    }
                }
            }
            .offset(x: m.side + m.trayPadding, y: m.top + m.trayPadding)

            NamePlate(text: name)
                .frame(width: m.width)
                .offset(y: m.height - m.front / 2 - 8.5)
        }
        .frame(width: m.width, height: m.height, alignment: .topLeading)
    }
}
