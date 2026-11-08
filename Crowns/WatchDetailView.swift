import SwiftUI
import SwiftData

/// Phase 1 detail: enough to check what was saved. Phase 3 rebuilds it.
struct WatchDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]
    let watch: Watch

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let data = watch.coverData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 360)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(watch.brand).font(.title3.weight(.semibold))
                    Text(watch.model).font(.title3)
                    if !watch.reference.isEmpty {
                        Text(watch.reference).font(.callout.monospaced()).foregroundStyle(.secondary)
                    }
                    Text(watch.priceLabel).font(.title3.monospacedDigit()).padding(.top, 6)
                }

                if !watch.specs.isEmpty {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        ForEach(watch.specs) { spec in
                            GridRow {
                                Text(spec.label).foregroundStyle(.secondary)
                                Text(spec.value)
                            }
                        }
                    }
                    .font(.subheadline)
                }

                let photos = watch.sortedPhotos
                if photos.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(photos) { photo in
                                Thumbnail(data: photo.data).frame(width: 96, height: 96)
                            }
                        }
                    }
                }

                if let url = watch.sourceURL {
                    Link(watch.sourceSiteName.isEmpty ? "Source" : watch.sourceSiteName, destination: url)
                }
            }
            .padding(20)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Menu("Move") {
                        ForEach(boxes.filter { $0.id != watch.box?.id }) { box in
                            Button(box.name) { move(to: box) }
                        }
                    }
                    Button("Remove", role: .destructive) { remove() }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }

    private func move(to box: Box) {
        let slot = box.claimFreeSlot()
        watch.box = box
        watch.slot = slot
        try? context.save()
    }

    private func remove() {
        context.delete(watch)
        try? context.save()
        dismiss()
    }
}
