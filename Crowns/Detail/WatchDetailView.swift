import SwiftUI
import SwiftData

/// A watch in its own sheet: a large cover, photos, specs, notes, the source
/// link, and Move / Edit / Remove.
struct WatchDetailView: View {
    let watch: Watch
    let onMove: (Watch, Box) -> Void
    let onRemove: (Watch) -> Void

    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]
    @State private var editing = false
    @State private var confirmRemove = false

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                WatchImage(watch: watch, size: .full)
                    .frame(height: 460)
                    .accessibilityLabel(watch.displayName)
                info
            }
            .padding(.bottom, Space.lg)
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(.container, edges: .top)
        .background(Theme.canvas)
        .safeAreaInset(edge: .bottom) { actions }
        .sheet(isPresented: $editing) {
            EditWatchSheet(watch: watch)
                .crownsSheet()
        }
        .confirmationDialog("Remove this watch?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { onRemove(watch) }
        }
    }

    // MARK: - Info

    private var info: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                if !watch.brand.isEmpty {
                    Text(watch.brand)
                        .font(Typeface.display)
                }
                if !watch.model.isEmpty {
                    Text(watch.model)
                        .font(.title3)
                        .foregroundStyle(Theme.inkSecondary)
                }
                if !watch.reference.isEmpty {
                    Text(watch.reference)
                        .font(Typeface.reference)
                        .foregroundStyle(Theme.inkTertiary)
                        .textSelection(.enabled)
                }
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, Space.xxs)

            if !watch.priceLabel.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(watch.priceLabel)
                        .font(Typeface.title.monospacedDigit())
                        .foregroundStyle(Theme.ink)
                    if watch.pricePence != nil, !watch.priceNote.isEmpty {
                        Text(watch.priceNote)
                            .font(Typeface.caption)
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }
                .padding(.horizontal, Space.xxs)
            }

            let photos = watch.sortedPhotos
            if photos.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: Space.sm) {
                        ForEach(photos) { photo in
                            DecodedImage(key: photo.id.uuidString, data: photo.data, maxPixel: 360, contentMode: .fill)
                                .frame(width: 104, height: 104)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                                .surface(radius: Radius.md)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }

            if !watch.specs.isEmpty {
                FormSection(title: "Specs", padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(watch.specs.enumerated()), id: \.element.id) { index, spec in
                            if index > 0 { RowDivider() }
                            ValueRow(title: spec.label, value: spec.value)
                        }
                    }
                }
            }

            if !watch.notes.isEmpty {
                FormSection(title: "Notes", padding: Space.md) {
                    Text(watch.notes)
                        .font(Typeface.body)
                        .foregroundStyle(Theme.ink)
                }
            }

            if let url = watch.sourceURL {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Text(watch.sourceSiteName.isEmpty ? (url.host() ?? "Source") : watch.sourceSiteName)
                        Image(systemName: "arrow.up.right")
                            .font(Typeface.micro)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill(.secondary))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.md)
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: Space.xs) {
            Menu {
                ForEach(boxes.filter { $0.id != watch.box?.id }) { box in
                    Button(box.name) { onMove(watch, box) }
                }
            } label: {
                Label("Move", systemImage: "arrow.left.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(.secondary))
            .disabled(boxes.count < 2)

            Button {
                editing = true
            } label: {
                Label("Edit", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill(.primary))
            .zIndex(1)

            Button {
                confirmRemove = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.circle(diameter: 54))
            .accessibilityLabel("Remove")
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, Space.md)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.xs)
        .background {
            // Content fades out before it reaches the buttons.
            LinearGradient(
                stops: [.init(color: Theme.canvas.opacity(0), location: 0), .init(color: Theme.canvas, location: 0.4)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
