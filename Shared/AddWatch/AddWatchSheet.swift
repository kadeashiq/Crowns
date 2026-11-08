import SwiftUI

/// One compact sheet: photos, brand and model, price, box, Save.
/// Everything is editable; nothing has to be. Most saves are two taps.
struct AddWatchSheet: View {
    @Bindable var model: AddWatchModel
    @FocusState private var focus: Field?

    private enum Field { case brand, model, price }

    var body: some View {
        NavigationStack {
            sheet.toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var sheet: some View {
        ZStack {
            Theme.deskBackground
            switch model.stage {
            case .paywall:
                ScrollView {
                    PaywallView(
                        store: model.store,
                        onFinish: { subscribed in Task { await model.paywallFinished(subscribed) } },
                        onCannotPurchase: model.isExtension ? { Task { await model.handOffToApp() } } : nil
                    )
                }
                .transition(.opacity)
            case .handedOff:
                handedOff.transition(.opacity)
            default:
                content.transition(.opacity)
            }
        }
        .background(ViewAnchor { model.hostView = $0 })
        .animation(Motion.standard, value: model.stage)
    }

    // MARK: - Main

    private var content: some View {
        VStack(spacing: 0) {
            header
            carousel
                .frame(height: 250)
            dots
                .frame(height: 18)
            fields
                .padding(.top, 6)
            boxPicker
                .padding(.top, 18)
            Spacer(minLength: 14)
            if !model.errorText.isEmpty {
                Text(model.errorText)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.85))
                    .padding(.bottom, 8)
            }
            saveButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var header: some View {
        ZStack {
            Text("Add watch")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            HStack {
                Button {
                    model.cancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Cancel")
                Spacer()
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    // MARK: - Photos

    @ViewBuilder
    private var carousel: some View {
        if model.photos.isEmpty {
            ZStack {
                Cushion(palette: FinishPalette.for(model.selectedFinish))
                    .frame(width: 170, height: 210)
                    .opacity(0.9)
                if model.photosLoading {
                    ProgressView().tint(Theme.inkSecondary)
                }
            }
            .transition(.opacity)
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(model.photos) { photo in
                        CarouselPage(photo: photo, cutout: model.cutouts[photo.id], finish: model.selectedFinish)
                            .containerRelativeFrame(.horizontal)
                            .id(photo.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $model.visiblePhotoID)
            .onChange(of: model.visiblePhotoID) { _, _ in
                Haptics.tick()
                model.coverChanged()
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var dots: some View {
        if model.photos.count > 1 {
            HStack(spacing: 6) {
                ForEach(model.photos) { photo in
                    Circle()
                        .fill(photo.id == model.visiblePhotoID ? Theme.ink : Theme.inkTertiary.opacity(0.6))
                        .frame(width: 5, height: 5)
                }
            }
            .animation(Motion.standard, value: model.visiblePhotoID)
        }
    }

    // MARK: - Fields

    private var fields: some View {
        VStack(spacing: 4) {
            TextField("Brand", text: $model.brand)
                .font(.title3.weight(.semibold))
                .focused($focus, equals: .brand)
            TextField("Model", text: $model.model)
                .font(.title3)
                .focused($focus, equals: .model)
            HStack(spacing: 2) {
                Text("£")
                    .foregroundStyle(Theme.inkSecondary)
                TextField("Price", text: $model.priceText)
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: .price)
                    .fixedSize()
            }
            .font(.body.monospacedDigit())
            .padding(.top, 6)
            if !model.priceNote.isEmpty {
                Text(model.priceNote)
                    .font(.caption)
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .multilineTextAlignment(.center)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .submitLabel(.done)
        .foregroundStyle(Theme.ink)
        .disabled(model.stage == .reading)
        .opacity(model.stage == .reading ? 0.4 : 1)
        .redacted(reason: model.stage == .reading ? .placeholder : [])
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
            }
        }
    }

    private var boxPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(model.boxes) { box in
                    let selected = box.id == model.selectedBoxID
                    Button {
                        Haptics.tick()
                        withAnimation(Motion.standard) { model.selectedBoxID = box.id }
                    } label: {
                        Text(box.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selected ? Theme.ink : Theme.inkSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selected ? Theme.brass.opacity(0.22) : Color.white.opacity(0.06), in: .capsule)
                            .overlay(Capsule().strokeBorder(selected ? Theme.brass.opacity(0.55) : .clear, lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var saveButton: some View {
        Button {
            focus = nil
            Task { await model.save() }
        } label: {
            ZStack {
                Text("Save").opacity(model.stage == .saved ? 0 : 1)
                Text("Saved").opacity(model.stage == .saved ? 1 : 0)
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.brass.opacity(0.85))
        .controlSize(.large)
        .disabled(model.stage == .reading || model.stage == .saving)
        .animation(Motion.standard, value: model.stage)
    }

    private var handedOff: some View {
        VStack(spacing: 14) {
            Image(systemName: "crown")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.brass)
            Text("Open Crowns to finish saving")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Button("Done") { model.close() }
                .buttonStyle(.glass)
                .controlSize(.large)
                .padding(.top, 6)
        }
        .padding(24)
    }
}

/// One photo in the carousel, resting on a cushion. When Vision has lifted
/// the watch out of it, the cut-out replaces the photo.
private struct CarouselPage: View {
    let photo: ImageFetcher.Photo
    let cutout: UIImage?
    let finish: BoxFinish

    var body: some View {
        ZStack {
            Cushion(palette: FinishPalette.for(finish))
                .frame(width: 170, height: 210)
            if let cutout {
                Image(uiImage: cutout)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 176, height: 196)
                    .shadow(color: .black.opacity(0.65), radius: 9, x: 0, y: 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                Image(uiImage: photo.preview)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 5)
                    .transition(.opacity)
            }
        }
        .animation(Motion.lift, value: cutout != nil)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
