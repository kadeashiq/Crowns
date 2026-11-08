import SwiftUI
import SwiftData

/// One box, shown as a grid or as a list.
struct BoxPage: View {
    let box: Box
    let mode: ViewMode
    let onOpen: (Watch) -> Void
    let onMove: (Watch, Box) -> Void
    let onRemove: (Watch) -> Void

    @Query(sort: \Watch.addedAt) private var allWatches: [Watch]
    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]

    private var watches: [Watch] {
        allWatches.filter { $0.box?.id == box.id }.sorted { ($0.slot, $0.addedAt) < ($1.slot, $1.addedAt) }
    }

    var body: some View {
        switch mode {
        case .box:
            BoxCanvas(box: box, watches: watches, onOpen: onOpen, menu: menu)
        case .list:
            WatchListView(watches: watches, onOpen: onOpen, menu: menu)
        }
    }

    @ViewBuilder
    private func menu(_ watch: Watch) -> some View {
        Menu("Move") {
            ForEach(boxes.filter { $0.id != box.id }) { other in
                Button(other.name) { onMove(watch, other) }
            }
        }
        Button("Remove", role: .destructive) { onRemove(watch) }
    }
}

/// The grid: one raised card per watch.
struct BoxCanvas<MenuContent: View>: View {
    let box: Box
    let watches: [Watch]
    let onOpen: (Watch) -> Void
    @ViewBuilder let menu: (Watch) -> MenuContent

    var body: some View {
        ScrollView(.vertical) {
            WatchGrid(columns: box.columns, watches: watches) { watch in
                WatchCell(watch: watch, columns: box.columns) {
                    onOpen(watch)
                }
                .contextMenu { menu(watch) }
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.md)
            .padding(.top, Space.xxs)
            .padding(.bottom, 112)

            if watches.isEmpty {
                Text("No watches in this box yet")
                    .font(Typeface.secondary)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// Dense rows: thumbnail, brand, model, reference, price.
struct WatchListView<MenuContent: View>: View {
    let watches: [Watch]
    let onOpen: (Watch) -> Void
    @ViewBuilder let menu: (Watch) -> MenuContent

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: Space.sm) {
                ForEach(watches) { watch in
                    Button {
                        onOpen(watch)
                    } label: {
                        WatchListRow(watch: watch)
                    }
                    .buttonStyle(CardButtonStyle(radius: Radius.md + 4))
                    .contextMenu { menu(watch) }
                }
                if watches.isEmpty {
                    Text("No watches in this box yet")
                        .font(Typeface.secondary)
                        .foregroundStyle(Theme.inkSecondary)
                        .padding(.top, Space.xxl)
                }
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.md)
            .padding(.top, Space.xxs)
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
    }
}

struct WatchListRow: View {
    let watch: Watch

    var body: some View {
        HStack(spacing: Space.sm) {
            WatchImage(watch: watch, size: .thumbnail)
                .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 1) {
                Text(watch.brand.isEmpty ? "—" : watch.brand)
                    .font(Typeface.label)
                    .foregroundStyle(Theme.ink)
                if !watch.model.isEmpty {
                    Text(watch.model)
                        .font(Typeface.secondary)
                        .foregroundStyle(Theme.inkSecondary)
                }
                if !watch.reference.isEmpty {
                    Text(watch.reference)
                        .font(Typeface.reference)
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
            .lineLimit(1)

            Spacer(minLength: Space.xs)

            Text(watch.priceLabel)
                .font(Typeface.price)
                .foregroundStyle(Theme.ink)
        }
        .padding(.trailing, Space.md)
        .clipShape(.rect(cornerRadius: Radius.md + 4, style: .continuous))
        .contentShape(.rect)
    }
}
