import SwiftUI

/// Sizes for a grid with a given number of columns.
struct GridMetrics {
    let columns: Int

    var showsCaption: Bool { columns <= 3 }
    var cardRadius: CGFloat { columns >= 3 ? Radius.md : Radius.lg }
    var captionInset: CGFloat { columns >= 3 ? Space.xs : Space.sm }

    /// Width over height for a whole cell, caption included.
    var aspectRatio: CGFloat {
        switch columns {
        case ...1: 1.15
        case 2: 0.78
        case 3: 0.66
        default: 0.8
        }
    }
}

/// The box's watches, filled row by row from the top left.
struct WatchGrid<Cell: View>: View {
    let columns: Int
    let watches: [Watch]
    @ViewBuilder var cell: (Watch) -> Cell

    private var items: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Space.sm), count: max(columns, 1))
    }

    var body: some View {
        LazyVGrid(columns: items, spacing: Space.sm) {
            ForEach(watches) { watch in
                cell(watch)
                    .aspectRatio(GridMetrics(columns: columns).aspectRatio, contentMode: .fit)
            }
        }
    }
}

/// A watch: its photo edge to edge on a raised card, with its name beneath.
struct WatchCell: View {
    let watch: Watch
    let columns: Int
    let onOpen: () -> Void

    private var metrics: GridMetrics { GridMetrics(columns: columns) }

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 0) {
                WatchImage(watch: watch)
                if metrics.showsCaption { caption }
            }
            .clipShape(.rect(cornerRadius: metrics.cardRadius, style: .continuous))
        }
        .buttonStyle(CardButtonStyle(radius: metrics.cardRadius))
        .accessibilityLabel(watch.displayName)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(watch.brand.isEmpty ? watch.displayName : watch.brand)
                .font(Typeface.micro)
                .foregroundStyle(Theme.ink)
            if columns <= 2, !detailLine.isEmpty {
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
