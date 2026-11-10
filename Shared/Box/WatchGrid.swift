import SwiftUI

/// Sizes for a card, set by the number of columns its box asks for.
struct GridMetrics {
    let columns: Int

    var showsCaption: Bool { columns <= 3 }
    var showsDetailLine: Bool { columns <= 2 }
    var cardRadius: CGFloat { columns >= 3 ? Radius.md : Radius.lg }
    var captionInset: CGFloat { columns >= 3 ? Space.xs : Space.sm }

    /// Width over height for a whole cell, caption included.
    var aspectRatio: CGFloat {
        switch columns {
        case ...1: return 1.15
        case 2: return 0.78
        case 3: return 0.66
        default: return 0.8
        }
    }

    /// The columns to lay out in a given width. A phone shows the box's own
    /// count; anything wider adds columns, so cards stay about the same size.
    static func columns(forWidth width: CGFloat, preferred: Int) -> Int {
        let preferred = max(preferred, 1)
        let phoneWidth: CGFloat = 402
        return max(preferred, Int(width / (phoneWidth / CGFloat(preferred))))
    }

    /// Decode sizes for a card's photo, smallest first.
    static let imageSteps = [240, 400, 560, 800]

    /// The pixels a card's photo needs along its longer side, in a grid this
    /// wide. Rounded up to a step, so nearby widths share one decoded image.
    func imagePixels(forWidth width: CGFloat, columns: Int, scale: CGFloat) -> Int {
        let columns = max(columns, 1)
        let card = (width - Space.md * 2 - Space.sm * CGFloat(columns - 1)) / CGFloat(columns)
        let longest = max(card, card / aspectRatio) * scale
        return GridMetrics.imageSteps.first { CGFloat($0) >= longest } ?? GridMetrics.imageSteps[GridMetrics.imageSteps.count - 1]
    }
}

/// The box's watches as a grid of cards. On iOS 27 and later, press and drag
/// a card to move it; the system runs the lift, the reflow and the drop.
struct WatchGrid<Cell: View>: View {
    /// The columns laid out, which can be more than the box asks for.
    let columns: Int
    let metrics: GridMetrics
    let watches: [Watch]
    /// Called with every watch in its new order once a card is dropped.
    let onReorder: ([Watch]) -> Void
    @ViewBuilder var cell: (Watch) -> Cell

    private var grid: CardGrid {
        CardGrid(columns: columns, spacing: Space.sm, aspectRatio: metrics.aspectRatio)
    }

    var body: some View {
        if #available(iOS 27.0, *) {
            grid {
                ForEach(watches, content: cell).reorderable()
            }
            .reorderContainer(for: Watch.self, itemID: \.id) { change in
                var anchor: UUID?
                if case .before(let id) = change.destination.position { anchor = id }
                onReorder(watches.placing(change.sources, before: anchor))
            }
        } else {
            grid {
                ForEach(watches, content: cell)
            }
        }
    }
}

/// A watch: its photo edge to edge on a raised card, with its name beneath.
struct WatchCell: View {
    let watch: Watch
    let metrics: GridMetrics
    /// See `GridMetrics.imagePixels`.
    var imagePixels: Int?
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 0) {
                WatchImage(watch: watch, pixels: imagePixels)
                if metrics.showsCaption { caption }
            }
            .clipShape(.rect(cornerRadius: metrics.cardRadius, style: .continuous))
        }
        .buttonStyle(CardButtonStyle(radius: metrics.cardRadius))
        // The lifted card keeps its rounded corners instead of a square backing.
        .contentShape(.dragPreview, .rect(cornerRadius: metrics.cardRadius, style: .continuous))
        .accessibilityLabel(watch.displayName)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(watch.brand.isEmpty ? watch.displayName : watch.brand)
                .font(Typeface.micro)
                .foregroundStyle(Theme.ink)
            if metrics.showsDetailLine, !detailLine.isEmpty {
                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .lineLimit(1)
        .padding(metrics.captionInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailLine: String {
        watch.model.isEmpty ? watch.priceLabel : watch.model
    }
}
