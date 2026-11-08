import SwiftUI
import SwiftData

/// The watch, lifted off its cushion: a large cover, photos, specs, notes,
/// the source link, and Move / Edit / Remove.
struct WatchDetailView: View {
    let watch: Watch
    let hero: Namespace.ID
    let onClose: () -> Void
    let onMove: (Watch, Box) -> Void
    let onRemove: (Watch) -> Void

    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]
    @State private var showInfo = false
    @State private var editing = false
    @State private var confirmRemove = false
    @State private var pull: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            Theme.deskBackground
                .opacity(showInfo ? 1 : 0.0)

            ScrollView {
                VStack(spacing: 0) {
                    cover
                        .padding(.top, 64)
                    if showInfo {
                        info
                            .padding(.top, 26)
                            .transition(.opacity.combined(with: .offset(y: 14)))
                    }
                }
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(pull > 0)

            topBar
                .opacity(showInfo ? 1 : 0)
        }
        .safeAreaInset(edge: .bottom) {
            if showInfo { actions.transition(.opacity) }
        }
        .onAppear {
            withAnimation(Motion.standard.delay(0.1)) { showInfo = true }
        }
        .sheet(isPresented: $editing) {
            EditWatchSheet(watch: watch)
        }
        .confirmationDialog("Remove this watch?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { onRemove(watch) }
        }
    }

    // MARK: - Cover

    private var cover: some View {
        DecodedImage(key: watch.coverKey, data: watch.coverData, maxPixel: WatchHeadMetrics.maxPixel)
            .clipShape(RoundedRectangle(cornerRadius: watch.coverIsCutout ? 0 : 18, style: .continuous))
            .matchedGeometryEffect(id: watch.id, in: hero)
            .shadow(color: .black.opacity(watch.coverIsCutout ? 0.6 : 0.4), radius: 22, x: 0, y: 18)
            .frame(maxWidth: .infinity)
            .frame(height: 340)
            .padding(.horizontal, watch.coverIsCutout ? 36 : 24)
            .offset(y: pull)
            .scaleEffect(1 - min(pull, 240) / 1600)
            .gesture(pullToClose)
            .accessibilityLabel(watch.displayName)
    }

    /// Pull the cover down to put the watch back.
    private var pullToClose: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                pull = max(value.translation.height, 0) * 0.6
            }
            .onEnded { value in
                if value.translation.height > 110 || value.predictedEndTranslation.height > 260 {
                    onClose()
                } else {
                    withAnimation(Motion.standard) { pull = 0 }
                }
            }
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.body.weight(.semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Close")
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Info

    private var info: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 3) {
                if !watch.brand.isEmpty {
                    Text(watch.brand)
                        .font(.title2.weight(.semibold))
                }
                if !watch.model.isEmpty {
                    Text(watch.model)
                        .font(.title3)
                }
                if !watch.reference.isEmpty {
                    Text(watch.reference)
                        .font(.callout.monospaced())
                        .foregroundStyle(Theme.inkSecondary)
                        .textSelection(.enabled)
                }
            }
            .foregroundStyle(Theme.ink)

            if !watch.priceLabel.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(watch.priceLabel)
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(Theme.ink)
                    if watch.pricePence != nil, !watch.priceNote.isEmpty {
                        Text(watch.priceNote)
                            .font(.caption)
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }
            }

            let photos = watch.sortedPhotos
            if photos.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(photos) { photo in
                            DecodedImage(key: photo.id.uuidString, data: photo.data, maxPixel: 360, contentMode: .fill)
                                .frame(width: 104, height: 104)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }

            if !watch.specs.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                    ForEach(watch.specs) { spec in
                        GridRow {
                            Text(spec.label)
                                .foregroundStyle(Theme.inkSecondary)
                            Text(spec.value)
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
                .font(.subheadline)
            }

            if !watch.notes.isEmpty {
                Text(watch.notes)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
            }

            if let url = watch.sourceURL {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Text(watch.sourceSiteName.isEmpty ? (url.host() ?? "Source") : watch.sourceSiteName)
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.brass)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - Actions

    private var actions: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(boxes.filter { $0.id != watch.box?.id }) { box in
                        Button(box.name) { onMove(watch, box) }
                    }
                } label: {
                    Label("Move", systemImage: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                Button {
                    editing = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                Button(role: .destructive) {
                    confirmRemove = true
                } label: {
                    Label("Remove", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .labelStyle(.titleAndIcon)
            .font(.subheadline.weight(.medium))
            .controlSize(.large)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}
