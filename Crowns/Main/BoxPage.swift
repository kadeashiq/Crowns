import SwiftUI
import SwiftData

/// One box, shown as a grid or as a list.
struct BoxPage: View {
    let box: Box
    /// Every box, for the Move menu.
    let boxes: [Box]
    let mode: ViewMode
    let onOpen: (Watch) -> Void
    let onMove: (Watch, Box) -> Void
    let onRemove: (Watch) -> Void

    @Environment(\.modelContext) private var context
    /// This box's watches only, so a change in another box leaves this page alone.
    @Query private var boxWatches: [Watch]

    init(
        box: Box,
        boxes: [Box],
        mode: ViewMode,
        onOpen: @escaping (Watch) -> Void,
        onMove: @escaping (Watch, Box) -> Void,
        onRemove: @escaping (Watch) -> Void
    ) {
        self.box = box
        self.boxes = boxes
        self.mode = mode
        self.onOpen = onOpen
        self.onMove = onMove
        self.onRemove = onRemove
        let boxID = box.id
        _boxWatches = Query(filter: #Predicate<Watch> { $0.box?.id == boxID }, sort: \Watch.addedAt)
    }

    private var watches: [Watch] {
        boxWatches.sorted { ($0.slot, $0.addedAt) < ($1.slot, $1.addedAt) }
    }

    var body: some View {
        switch mode {
        case .box:
            BoxCanvas(box: box, watches: watches, onOpen: onOpen, onReorder: arrange)
        case .list:
            WatchListView(watches: watches, onOpen: onOpen, menu: menu)
        }
    }

    /// Keeps the order the cards were dragged into.
    private func arrange(_ ordered: [Watch]) {
        box.seat(ordered)
        try? context.save()
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

/// The grid: one raised card per watch. Press and drag a card to move it;
/// Move and Remove are on the watch's own screen.
struct BoxCanvas: View {
    let box: Box
    let watches: [Watch]
    let onOpen: (Watch) -> Void
    let onReorder: ([Watch]) -> Void

    @Environment(\.contentWidth) private var contentWidth
    @Environment(\.displayScale) private var displayScale
    @State private var width: CGFloat = 0

    private var metrics: GridMetrics { GridMetrics(columns: box.columns) }

    /// Before the page is measured, photos are sized for a phone.
    private var imagePixels: Int {
        let measured = width == 0 ? 402 : min(width, contentWidth)
        let columns = GridMetrics.columns(forWidth: measured, preferred: box.columns)
        return metrics.imagePixels(forWidth: measured, columns: columns, scale: displayScale)
    }

    var body: some View {
        ScrollView(.vertical) {
            WatchGrid(
                columns: GridMetrics.columns(forWidth: min(width, contentWidth), preferred: box.columns),
                metrics: metrics,
                watches: watches,
                onReorder: onReorder
            ) { watch in
                WatchCell(watch: watch, metrics: metrics, imagePixels: imagePixels) {
                    onOpen(watch)
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.top, Space.xxs)
            .padding(.bottom, Space.md)
            .contentColumn()

            if watches.isEmpty {
                Text("Nothing here yet. Tap + to add a watch.")
                    .font(Typeface.secondary)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .scrollIndicators(.hidden)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

/// Dense rows: thumbnail, brand, model, reference, price.
struct WatchListView<MenuContent: View>: View {
    let watches: [Watch]
    let onOpen: (Watch) -> Void
    @ViewBuilder let menu: (Watch) -> MenuContent

    var body: some View {
        ScrollView(.vertical) {
            // One column on a phone, more as the window widens.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: Space.sm)], spacing: Space.sm) {
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
                    Text("Nothing here yet. Tap + to add a watch.")
                        .font(Typeface.secondary)
                        .foregroundStyle(Theme.inkSecondary)
                        .padding(.top, Space.xxl)
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.top, Space.xxs)
            .padding(.bottom, Space.md)
            .contentColumn()
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
