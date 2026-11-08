import SwiftUI

/// One compact sheet: photos, brand and model, price, box, Save.
/// Everything is editable; nothing has to be. Most saves are two taps.
struct AddWatchSheet: View {
    @Bindable var model: AddWatchModel
    @FocusState private var focus: Field?
    @Namespace private var boxSelection

    private enum Field { case brand, model, reference, price, notes }

    var body: some View {
        NavigationStack {
            sheet.toolbar(.hidden, for: .navigationBar)
        }
    }

    private var sheet: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            content
        }
        .background(ViewAnchor { model.hostView = $0 })
    }

    // MARK: - Main

    private var content: some View {
        VStack(spacing: 0) {
            if model.isExtension {
                // Extensions don't get the system's indicator.
                Capsule()
                    .fill(Theme.inkTertiary.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 5)
            }
            SheetHeader(title: "Add watch")
            ScrollView {
                VStack(spacing: 0) {
                    carousel
                        .frame(height: 280)
                        .padding(.horizontal, -(Space.lg - 4))
                    photoChooser
                    fields
                        .padding(.top, Space.md)
                    boxPicker
                        .padding(.top, Space.md)
                }
                .padding(.horizontal, Space.lg - 4)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            if !model.errorText.isEmpty {
                Text(model.errorText)
                    .font(Typeface.caption)
                    .foregroundStyle(Theme.ink)
                    .padding(.top, Space.xs)
            }
            // While typing, the keyboard's Done takes its place.
            if focus == nil {
                saveButton
                    .padding(.horizontal, Space.lg - 4)
                    .padding(.vertical, Space.sm)
            }
        }
    }

    // MARK: - Photos

    @ViewBuilder
    private var carousel: some View {
        if model.photos.isEmpty {
            Theme.well.overlay {
                if model.photosLoading {
                    ProgressView().tint(Theme.inkSecondary)
                }
            }
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(model.photos) { photo in
                        CarouselPage(photo: photo)
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
            }
        }
    }

    /// Picks the one photo to save. Swiping the carousel does the same.
    @ViewBuilder
    private var photoChooser: some View {
        if model.photos.count > 1 {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Pick your cover photo")
                    .font(Typeface.label)
                    .foregroundStyle(Theme.inkSecondary)
                ScrollView(.horizontal) {
                    HStack(spacing: Space.xs) {
                        ForEach(Array(model.photos.enumerated()), id: \.element.id) { index, photo in
                            thumbnail(photo, number: index + 1)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .fullBleed()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Space.sm)
        }
    }

    private func thumbnail(_ photo: ImageFetcher.Photo, number: Int) -> some View {
        let selected = photo.id == model.visiblePhotoID
        return Button {
            model.visiblePhotoID = photo.id
        } label: {
            Image(uiImage: photo.preview)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(.rect(cornerRadius: Radius.sm, style: .continuous))
                .opacity(selected ? 1 : 0.5)
                .padding(3)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm + 3, style: .continuous)
                        .strokeBorder(Theme.ink, lineWidth: selected ? 2 : 0)
                )
                .overlay(alignment: .bottomTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Theme.onInk, Theme.ink)
                            .offset(x: 2, y: 2)
                    }
                }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Photo \(number)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Fields

    private var fields: some View {
        Card(padding: Space.xs + 2) {
            VStack(spacing: Space.xs) {
                row("Brand", text: $model.brand, focus: .brand)
                row("Model", text: $model.model, focus: .model)
                row("Reference", text: $model.reference, focus: .reference)
                    .autocorrectionDisabled()
                row("Price", text: $model.priceText, focus: .price, prefix: "£")
                    .keyboardType(.decimalPad)
                if !model.priceNote.isEmpty {
                    Text(model.priceNote)
                        .font(.caption)
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, Space.xxs)
                }
                HStack(alignment: .top, spacing: Space.sm) {
                    rowLabel("Notes")
                    TextField("Notes", text: $model.notes, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($focus, equals: .notes)
                }
                .padding(.vertical, Space.sm)
                .filledField()
                .textInputAutocapitalization(.sentences)
            }
        }
        .textInputAutocapitalization(.words)
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

    private func row(_ title: String, text: Binding<String>, focus field: Field, prefix: String? = nil) -> some View {
        HStack(spacing: Space.sm) {
            rowLabel(title)
            if let prefix {
                Text(prefix).foregroundStyle(Theme.inkSecondary)
            }
            TextField(title, text: text)
                .focused($focus, equals: field)
        }
        .filledField()
    }

    private func rowLabel(_ title: String) -> some View {
        Text(title)
            .font(Typeface.secondary)
            .foregroundStyle(Theme.inkSecondary)
            .frame(width: 80, alignment: .leading)
    }

    private var boxPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.xs) {
                ForEach(model.boxes) { box in
                    Button {
                        Haptics.tick()
                        model.selectedBoxID = box.id
                    } label: {
                        Chip(title: box.name, selected: box.id == model.selectedBoxID, namespace: boxSelection)
                    }
                    .buttonStyle(PressableStyle())
                    .zIndex(box.id == model.selectedBoxID ? 1 : 0)
                }
            }
            .animation(Motion.selection, value: model.selectedBoxID)
            // Room for the chips' shadows inside the scroll area.
            .padding(.vertical, Space.xl)
        }
        .scrollIndicators(.hidden)
        .fullBleed()
        .padding(.vertical, Space.sm - Space.xl)
    }

    private var saveButton: some View {
        Button {
            focus = nil
            Task { await model.save() }
        } label: {
            ZStack {
                Text("Save").opacity(model.stage == .saved ? 0 : 1)
                Label("Saved", systemImage: "checkmark")
                    .opacity(model.stage == .saved ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pill())
        .disabled(model.stage == .reading || model.stage == .saving)
    }
}

private extension View {
    /// Runs a horizontal row to the sheet's edges, with its content still
    /// lined up with the margins.
    func fullBleed() -> some View {
        contentMargins(.horizontal, Space.lg - 4, for: .scrollContent)
            .padding(.horizontal, -(Space.lg - 4))
    }
}

/// One photo in the carousel, filling the page.
private struct CarouselPage: View {
    let photo: ImageFetcher.Photo

    var body: some View {
        Theme.well
            .overlay {
                Image(uiImage: photo.preview)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
    }
}
