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
        .fadingBar(.top) {
            VStack(spacing: 0) {
                if model.isExtension {
                    // Extensions don't get the system's indicator.
                    Capsule()
                        .fill(Theme.inkTertiary.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 5)
                }
                SheetHeader(title: "Add watch")
            }
        }
        .fadingBar(.bottom) {
            // While typing, the keyboard's Done takes its place.
            if focus == nil {
                VStack(spacing: Space.xs) {
                    if !model.errorText.isEmpty {
                        Text(model.errorText)
                            .font(Typeface.caption)
                            .foregroundStyle(Theme.ink)
                    }
                    saveButton
                }
                .padding(.horizontal, Space.lg - 4)
                .padding(.bottom, Space.sm)
            }
        }
    }

    // MARK: - Photos

    @ViewBuilder
    private var carousel: some View {
        if model.photos.isEmpty {
            Theme.hairline.overlay { photoStatus }
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

    @ViewBuilder
    private var photoStatus: some View {
        VStack(spacing: Space.sm) {
            if let message = model.loadingMessage {
                ProgressView()
                    .controlSize(.large)
                    .tint(Theme.inkSecondary)
                Text(message)
                    .font(Typeface.label)
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                Image(systemName: "photo")
                    .font(Typeface.title)
                    .foregroundStyle(Theme.inkTertiary)
                Text(model.foundNothing ? "Couldn't read this page" : "No photos found")
                    .font(Typeface.label)
                    .foregroundStyle(Theme.ink)
                if model.foundNothing {
                    Text("Add the details yourself below.")
                        .font(Typeface.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
    }

    /// Picks the one photo to save. Swiping the carousel does the same.
    @ViewBuilder
    private var photoChooser: some View {
        if model.photos.count > 1 || model.loadingMessage != nil {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Pick your cover photo")
                    .font(Typeface.label)
                    .foregroundStyle(Theme.inkSecondary)
                ScrollView(.horizontal) {
                    HStack(spacing: Space.xs) {
                        if model.photos.isEmpty {
                            ForEach(0..<6, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .fill(Theme.hairline)
                                    .frame(width: 52, height: 52)
                                    .padding(3)
                            }
                        } else {
                            ForEach(Array(model.photos.enumerated()), id: \.element.id) { index, photo in
                                thumbnail(photo, number: index + 1)
                            }
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
                row("Brand", text: $model.brand, focus: .brand, skeletonWidth: 90)
                row("Model", text: $model.model, focus: .model, skeletonWidth: 150)
                row("Reference", text: $model.reference, focus: .reference, skeletonWidth: 110)
                    .autocorrectionDisabled()
                row("Price", text: $model.priceText, focus: .price, prefix: "£", skeletonWidth: 70)
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
            }
        }
    }

    private func row(_ title: String, text: Binding<String>, focus field: Field, prefix: String? = nil, skeletonWidth: CGFloat) -> some View {
        HStack(spacing: Space.sm) {
            rowLabel(title)
            if model.stage == .reading {
                SkeletonBar(width: skeletonWidth)
                Spacer(minLength: 0)
            } else {
                if let prefix {
                    Text(prefix).foregroundStyle(Theme.inkSecondary)
                }
                TextField(title, text: text)
                    .focused($focus, equals: field)
            }
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
            saveLabel
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pill())
        .disabled(!model.canSave && model.stage != .saved)
    }

    @ViewBuilder
    private var saveLabel: some View {
        switch model.stage {
        case .saving:
            HStack(spacing: Space.xs) {
                ProgressView().tint(Theme.inkTertiary)
                Text("Saving")
            }
        case .saved:
            Label("Saved", systemImage: "checkmark")
        default:
            Text(model.loadingMessage == nil ? "Save" : "Loading…")
        }
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
