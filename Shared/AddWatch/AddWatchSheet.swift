import SwiftUI

/// The form in the share extension, which has no navigation of its own.
struct AddWatchSheet: View {
    @Bindable var model: AddWatchModel

    var body: some View {
        NavigationStack {
            AddWatchForm(model: model)
        }
        .tint(Theme.ink)
        .overlay(alignment: .top) {
            // Extensions don't get the system's indicator.
            Capsule()
                .fill(Theme.inkTertiary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 5)
        }
    }
}

/// One standard form: photos, box, details, notes. Everything is editable;
/// nothing has to be. Most saves are two taps.
struct AddWatchForm: View {
    @Bindable var model: AddWatchModel
    /// Rows for adding a photo by hand, from the app.
    var photoActions: AnyView? = nil
    @FocusState private var focus: Field?

    private enum Field: Hashable { case brand, model, reference, price, notes, spec(UUID) }

    private static let typingSuggestionsID = "typing-suggestions"

    var body: some View {
        ScrollViewReader { proxy in
            form
                .onChange(of: focus) { _, field in
                    guard field == .brand || field == .model else { return }
                    // Once the keyboard is up, so the suggestions clear it.
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        withAnimation { proxy.scrollTo(Self.typingSuggestionsID, anchor: .center) }
                    }
                }
        }
        .navigationTitle("Add watch")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { saveButton }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
            }
        }
        .sensoryFeedback(.selection, trigger: model.visiblePhotoID)
        .background(ViewAnchor { model.hostView = $0 })
    }

    private var form: some View {
        Form {
            if !model.isManual || !model.photos.isEmpty {
                Section {
                    carousel
                        .frame(height: 280)
                        .listRowInsets(EdgeInsets())
                }
            }
            photoChooser
            if let photoActions {
                Section { photoActions }
            }
            detailsSection
            specsSection
            Section {
                TextField("Notes", text: $model.notes, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focus, equals: .notes)
                    .textInputAutocapitalization(.sentences)
            }
            .disabled(model.stage == .reading)
        }
        .listSectionSpacing(.compact)
        .scrollDismissesKeyboard(.interactively)
        .animation(.default, value: focus)
    }

    // MARK: - Photos

    @ViewBuilder
    private var carousel: some View {
        if model.photos.isEmpty {
            photoStatus
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        }
    }

    @ViewBuilder
    private var photoStatus: some View {
        if let message = model.loadingMessage {
            VStack(spacing: Space.sm) {
                ProgressView()
                    .controlSize(.large)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if model.foundNothing {
            ContentUnavailableView("Couldn't read this page", systemImage: "photo", description: Text("Add the details below."))
        } else {
            ContentUnavailableView("No photos found", systemImage: "photo")
        }
    }

    /// Picks the one photo to save. Swiping the carousel does the same.
    @ViewBuilder
    private var photoChooser: some View {
        if model.photos.count > 1 {
            Section("Pick your cover photo") {
                ScrollView(.horizontal) {
                    HStack(spacing: Space.xs) {
                        ForEach(Array(model.photos.enumerated()), id: \.element.id) { index, photo in
                            thumbnail(photo, number: index + 1)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
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
        .buttonStyle(.borderless)
        .accessibilityLabel("Photo \(number)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Fields

    /// The boxes to save into. A section header rather than a row of its own:
    /// a form row cuts off the chips' shadows at its edges.
    private var boxPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.xs) {
                ForEach(model.boxes) { box in
                    ChipButton(title: box.name, selected: box.id == model.selectedBoxID) {
                        Haptics.tick()
                        model.selectedBoxID = box.id
                    }
                    // Keeps the next chip's shadow off the selected one.
                    .zIndex(box.id == model.selectedBoxID ? 1 : 0)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .textCase(nil)
        // The same gap above as below, where the next card starts.
        .listRowInsets(EdgeInsets(top: Space.xs - 2, leading: 0, bottom: Space.sm, trailing: 0))
    }

    private var detailsSection: some View {
        Section {
            Group {
                row("Brand", placeholder: "Add brand", text: $model.brand, focus: .brand, next: .model)
                    .autocorrectionDisabled()
                typingSuggestions(for: .brand)
                pageSuggestions(for: "Brand", unless: .brand)
                row("Model", placeholder: "Add model", text: $model.model, focus: .model, next: .reference)
                    .autocorrectionDisabled()
                typingSuggestions(for: .model)
                pageSuggestions(for: "Model", unless: .model)
                row("Reference", placeholder: "Optional", text: $model.reference, focus: .reference, next: .price)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                pageSuggestions(for: "Reference", unless: .reference)
                row("Price (£)", placeholder: "Optional", text: $model.priceText, focus: .price)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Price")
            }
            .disabled(model.stage == .reading)
        } header: {
            boxPicker
        } footer: {
            if !model.errorText.isEmpty {
                Text(model.errorText)
            } else if !model.priceNote.isEmpty {
                Text(model.priceNote)
            }
        }
        .textInputAutocapitalization(.words)
    }

    private var specsSection: some View {
        Section {
            ForEach($model.specs) { $spec in
                specRow($spec)
                if !spec.isCustom {
                    pageSuggestions(for: spec.label, unless: .spec(spec.id))
                }
            }
            Menu {
                ForEach(model.unusedSpecLabels, id: \.self) { label in
                    Button(label) { model.addSpec(label) }
                }
                Divider()
                Button("Other") { model.addSpec(nil) }
            } label: {
                Label("Add spec", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
        } header: {
            Text("Specs")
        } footer: {
            if model.hasSuggestions {
                Text("Found on the page, but not for certain. Nothing is saved unless you tap it.")
            }
        }
        .textInputAutocapitalization(.sentences)
        .disabled(model.stage == .reading)
    }

    @ViewBuilder
    private func specRow(_ spec: Binding<EditableSpec>) -> some View {
        let id = spec.wrappedValue.id
        if spec.wrappedValue.isCustom {
            HStack(spacing: Space.sm) {
                TextField("Label", text: spec.label)
                specValueField(spec, id: id, accessibilityTitle: "Value")
            }
        } else {
            LabeledContent(spec.wrappedValue.label) {
                if model.stage == .reading {
                    Text("Reading listing")
                        .redacted(reason: .placeholder)
                } else {
                    specValueField(spec, id: id, accessibilityTitle: spec.wrappedValue.label)
                }
            }
        }
    }

    private func specValueField(_ spec: Binding<EditableSpec>, id: UUID, accessibilityTitle: String) -> some View {
        TextField("Optional", text: spec.value, axis: .vertical)
            .lineLimit(1...3)
            .multilineTextAlignment(.trailing)
            .focused($focus, equals: .spec(id))
            .accessibilityLabel(accessibilityTitle)
    }

    private func row(_ title: String, placeholder: String, text: Binding<String>, focus field: Field, next: Field? = nil) -> some View {
        LabeledContent(title) {
            if model.stage == .reading {
                Text("Reading listing")
                    .redacted(reason: .placeholder)
            } else {
                TextField(placeholder, text: text)
                    .multilineTextAlignment(.trailing)
                    .focused($focus, equals: field)
                    .submitLabel(next == nil ? .done : .next)
                    .onSubmit { focus = next }
                    .accessibilityLabel(title)
            }
        }
    }

    private var typingMatches: [WatchCatalog.Match] {
        switch focus {
        case .brand: WatchCatalog.brands(matching: model.brand)
        case .model: WatchCatalog.models(matching: model.model, brand: model.brand)
        default: []
        }
    }

    /// Brands or models that fit what's been typed, under the field in use.
    @ViewBuilder
    private func typingSuggestions(for field: Field) -> some View {
        let matches = focus == field ? typingMatches : []
        if !matches.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: Space.xs) {
                    ForEach(matches) { match in
                        ChipButton(title: match.model.isEmpty || model.brand.isEmpty ? match.title : match.model, flat: true) {
                            model.apply(match)
                            if focus == .brand { focus = .model }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .id(Self.typingSuggestionsID)
        }
    }

    /// Values the page gave for an empty field it wasn't clear about. Out of
    /// the way while the field is being typed in.
    @ViewBuilder
    private func pageSuggestions(for field: String, unless typing: Field) -> some View {
        let values = focus == typing ? [] : model.suggestions(for: field)
        if !values.isEmpty {
            HStack(spacing: Space.xs) {
                Text("From the page")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                ScrollView(.horizontal) {
                    HStack(spacing: Space.xs) {
                        ForEach(values, id: \.self) { value in
                            ChipButton(title: value, flat: true) {
                                model.use(value, for: field)
                            }
                            .accessibilityLabel("Use \(value) for \(field)")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: - Saving

    @ViewBuilder
    private var saveButton: some View {
        switch model.stage {
        case .saving:
            ProgressView()
        case .saved:
            Image(systemName: "checkmark")
                .accessibilityLabel("Saved")
        default:
            Button("Save") {
                focus = nil
                Task { await model.save() }
            }
            .disabled(!model.canSave)
        }
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
