import SwiftUI
import SwiftData

/// One box, shown as the physical box or as a list.
struct BoxPage: View {
    let box: Box
    let mode: ViewMode
    let hero: Namespace.ID
    let focusedID: UUID?
    let onOpen: (Watch) -> Void
    let onAdd: (Int?) -> Void
    let onMove: (Watch, Box) -> Void
    let onRemove: (Watch) -> Void

    @Query(sort: \Watch.addedAt) private var allWatches: [Watch]
    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]

    private var watches: [Watch] {
        allWatches.filter { $0.box?.id == box.id }.sorted { ($0.slot, $0.addedAt) < ($1.slot, $1.addedAt) }
    }

    var body: some View {
        ZStack {
            switch mode {
            case .box:
                BoxCanvas(box: box, watches: watches, hero: hero, focusedID: focusedID, onOpen: onOpen, onAdd: { onAdd($0) }, menu: menu)
                    .transition(.opacity)
            case .list:
                WatchListView(watches: watches, hero: hero, focusedID: focusedID, onOpen: onOpen, onAdd: { onAdd(nil) }, menu: menu)
                    .transition(.opacity)
            }
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

/// The physical box, sized to the width of a phone held in one hand.
struct BoxCanvas<MenuContent: View>: View {
    let box: Box
    let watches: [Watch]
    let hero: Namespace.ID
    let focusedID: UUID?
    let onOpen: (Watch) -> Void
    let onAdd: (Int) -> Void
    @ViewBuilder let menu: (Watch) -> MenuContent

    var body: some View {
        let bySlot = Dictionary(watches.map { ($0.slot, $0) }, uniquingKeysWith: { first, _ in first })
        let lastSlot = bySlot.keys.max() ?? 0
        let rows = max(box.rows, lastSlot / max(box.columns, 1) + 1)
        GeometryReader { geo in
            ScrollView(.vertical) {
                WatchBoxView(name: box.name, finish: box.finish, seed: box.id, columns: box.columns, rows: rows, width: min(geo.size.width - 32, 520)) { slot in
                    if let watch = bySlot[slot] {
                        Button {
                            onOpen(watch)
                        } label: {
                            WatchHead(
                                key: watch.coverKey,
                                data: watch.coverData,
                                isCutout: watch.coverIsCutout,
                                hero: focusedID == watch.id ? nil : HeroLink(id: watch.id, namespace: hero)
                            )
                            .opacity(focusedID == watch.id ? 0 : 1)
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu { menu(watch) }
                        .accessibilityLabel(watch.displayName)
                    } else {
                        Button {
                            onAdd(slot)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .light))
                                .foregroundStyle(.white.opacity(0.16))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Add watch")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// Dense rows: thumbnail, brand, model, reference, price; total at the bottom.
struct WatchListView<MenuContent: View>: View {
    let watches: [Watch]
    let hero: Namespace.ID
    let focusedID: UUID?
    let onOpen: (Watch) -> Void
    let onAdd: () -> Void
    @ViewBuilder let menu: (Watch) -> MenuContent

    var body: some View {
        List {
            ForEach(watches) { watch in
                Button {
                    onOpen(watch)
                } label: {
                    WatchListRow(watch: watch, hero: focusedID == watch.id ? nil : HeroLink(id: watch.id, namespace: hero))
                        .opacity(focusedID == watch.id ? 0 : 1)
                }
                .buttonStyle(.plain)
                .contextMenu { menu(watch) }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Theme.hairline)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            Button(action: onAdd) {
                Label("Add watch", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            if !watches.isEmpty { total }
        }
    }

    private var total: some View {
        let pence = watches.compactMap(\.pricePence).reduce(0, +)
        return HStack {
            Text(watches.count == 1 ? "1 watch" : "\(watches.count) watches")
                .foregroundStyle(Theme.inkSecondary)
            Spacer()
            Text(PriceFormatter.pounds(pence: pence))
                .foregroundStyle(Theme.ink)
        }
        .font(.subheadline.monospacedDigit())
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

struct WatchListRow: View {
    let watch: Watch
    let hero: HeroLink?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                DecodedImage(key: watch.thumbnailKey, data: watch.thumbnailData, maxPixel: 240, contentMode: watch.coverIsCutout ? .fit : .fill)
                    .padding(watch.coverIsCutout ? 3 : 0)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .hero(hero)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 1) {
                Text(watch.brand.isEmpty ? "—" : watch.brand)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                if !watch.model.isEmpty {
                    Text(watch.model)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                }
                if !watch.reference.isEmpty {
                    Text(watch.reference)
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
            .lineLimit(1)

            Spacer(minLength: 8)

            Text(watch.priceLabel)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.inkSecondary)
        }
        .contentShape(Rectangle())
    }
}

/// A small, soft press: the cushion gives a little under the finger.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Motion.standard, value: configuration.isPressed)
    }
}
