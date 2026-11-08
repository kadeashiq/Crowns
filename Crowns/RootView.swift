import SwiftUI
import SwiftData

/// Phase 1: a plain list to confirm saves from the share extension land.
/// Phase 2 replaces this with the box view.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshID = UUID()
    @State private var seenStamp = ExternalChanges.stamp

    var body: some View {
        NavigationStack {
            BoxList()
                .id(refreshID)
                .navigationTitle("Crowns")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            DiagnosticsView()
                        } label: {
                            Image(systemName: "doc.text.magnifyingglass")
                        }
                        .accessibilityLabel("Diagnostics")
                    }
                }
                .navigationDestination(for: Watch.self) { watch in
                    WatchDetailView(watch: watch)
                }
        }
        .task { BoxSeeder.ensureDefaults(in: context) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { pickUpExternalChanges() }
        }
    }

    /// The extension writes to the store from another process. Re-running the
    /// queries makes its inserts appear without relaunching.
    private func pickUpExternalChanges() {
        let stamp = ExternalChanges.stamp
        guard stamp > seenStamp else { return }
        seenStamp = stamp
        BoxSeeder.mergeDuplicateSeeds(in: context)
        refreshID = UUID()
    }
}

private struct BoxList: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]
    @Query(sort: \Watch.addedAt, order: .reverse) private var watches: [Watch]

    var body: some View {
        List {
            ForEach(boxes) { box in
                let items = watches
                    .filter { $0.box?.id == box.id }
                    .sorted { $0.slot < $1.slot }
                Section {
                    ForEach(items) { watch in
                        NavigationLink(value: watch) {
                            WatchRow(watch: watch)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(items[index]) }
                        try? context.save()
                    }
                } header: {
                    HStack {
                        Text(box.name)
                        Spacer()
                        Text(total(of: items))
                    }
                }
            }
        }
    }

    private func total(of items: [Watch]) -> String {
        let pence = items.compactMap(\.pricePence).reduce(0, +)
        return pence > 0 ? PriceFormatter.pounds(pence: pence) : ""
    }
}

struct WatchRow: View {
    let watch: Watch

    var body: some View {
        HStack(spacing: 12) {
            Thumbnail(data: watch.thumbnailData)
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(watch.brand.isEmpty ? "—" : watch.brand)
                    .font(.subheadline.weight(.semibold))
                Text(watch.model.isEmpty ? " " : watch.model)
                    .font(.subheadline)
                if !watch.reference.isEmpty {
                    Text(watch.reference)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            Spacer()
            Text(watch.priceLabel)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

struct Thumbnail: View {
    let data: Data?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06))
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            }
        }
    }
}

extension Watch {
    /// "£12,950", or the original foreign price while conversion is pending.
    var priceLabel: String {
        if let pricePence { return PriceFormatter.pounds(pence: pricePence) }
        return priceNote
    }
}
