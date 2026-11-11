import SwiftUI
import SwiftData
import PhotosUI

struct EditWatchSheet: View {
    let watch: Watch

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var brand = ""
    @State private var model = ""
    @State private var reference = ""
    @State private var price = ""
    @State private var notes = ""
    @State private var source = ""
    @State private var specs: [EditableSpec] = []
    @State private var cover = Cover.current
    @State private var newPhoto: ImageFetcher.Photo?
    @State private var photoError = ""
    @State private var isTakingPhoto = false
    @State private var choosingSource = false
    @State private var isPickingPhoto = false
    @State private var photoItem: PhotosPickerItem?
    @State private var working = false

    /// Which photo becomes the cover.
    private enum Cover: Equatable {
        case current
        case saved(UUID)
        /// Taken or chosen just now.
        case new
    }

    private struct EditableSpec: Identifiable {
        let id = UUID()
        var label: String
        var value: String
    }

    var body: some View {

        ScrollView {
            VStack(spacing: Space.lg) {
                photo

                FormSection(title: "Watch") {
                    VStack(spacing: Space.xs) {
                        TextField("Brand", text: $brand).filledField()
                        TextField("Model", text: $model).filledField()
                        TextField("Reference", text: $reference)
                            .filledField()
                            .font(.body.monospaced())
                    }
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                }

                FormSection(title: "Price", footer: watch.priceNote) {
                    HStack(spacing: 4) {
                        Text("£").foregroundStyle(Theme.inkSecondary)
                        TextField("Price", text: $price).keyboardType(.decimalPad)
                    }
                    .filledField()
                }

                specsSection

                FormSection(title: "Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                        .padding(.vertical, Space.sm)
                        .filledField()
                }

                FormSection(title: "Source") {
                    TextField("Link", text: $source)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .filledField()
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xl)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .fadingBar(.top) {
            SheetHeader(title: "Edit") {
                if working {
                    ProgressView().frame(width: 72, height: 40)
                } else {
                    Button("Save") { Task { await save() } }
                        .buttonStyle(.pill(.primary, size: .small))
                }
            }
        }
        .background(Theme.canvas)
        .onAppear(perform: load)
    }

    /// The cover as it will be saved, with a way to replace it.
    private var photo: some View {
        VStack(spacing: Space.sm) {
            Theme.well
                .overlay { coverImage }
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        choosingSource = true
                    } label: {
                        Label(hasPhoto ? "Replace" : "Add photo", systemImage: "photo")
                    }
                    .buttonStyle(.pill(.secondary, size: .small))
                    .padding(Space.sm)
                }

            // Older watches kept every photo from their page.
            let photos = watch.sortedPhotos
            if photos.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: Space.sm) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            tile(.saved(photo.id), label: "Photo \(index + 1)") {
                                DecodedImage(key: photo.id.uuidString, bytes: .photo(photo), maxPixel: 360, contentMode: .fill)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if !photoError.isEmpty {
                Text(photoError)
                    .font(Typeface.caption)
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .confirmationDialog(hasPhoto ? "Replace photo" : "Add photo", isPresented: $choosingSource) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { isTakingPhoto = true }
            }
            Button("Choose from Library") { isPickingPhoto = true }
        }
        .photosPicker(isPresented: $isPickingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                let loaded = try? await item.loadTransferable(type: Data.self)
                if let data = loaded ?? nil {
                    usePhoto(data)
                } else {
                    photoError = "Couldn't read that photo"
                }
                photoItem = nil
            }
        }
        .fullScreenCover(isPresented: $isTakingPhoto) {
            CameraPicker { image in
                isTakingPhoto = false
                guard let image else { return }
                Task {
                    let data = await Task.detached(priority: .userInitiated) {
                        image.jpegData(compressionQuality: 0.9)
                    }.value
                    if let data {
                        usePhoto(data)
                    } else {
                        photoError = "Couldn't read that photo"
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private var hasPhoto: Bool { watch.hasCover || newPhoto != nil }

    @ViewBuilder
    private var coverImage: some View {
        switch cover {
        case .new:
            if let newPhoto {
                Image(uiImage: newPhoto.preview)
                    .resizable()
                    .scaledToFill()
            }
        case .saved(let id):
            if let photo = watch.sortedPhotos.first(where: { $0.id == id }) {
                DecodedImage(key: photo.id.uuidString, bytes: .photo(photo), maxPixel: 1400, contentMode: .fill)
            }
        case .current:
            if watch.hasCover {
                WatchImage(watch: watch, size: .full)
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
    }

    private func tile(_ choice: Cover, label: String, @ViewBuilder image: () -> some View) -> some View {
        let selected = cover == choice
        return Button {
            Haptics.tick()
            cover = choice
        } label: {
            image()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .padding(3)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm + 3, style: .continuous)
                        .strokeBorder(Theme.ink, lineWidth: selected ? 2 : 0)
                )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func usePhoto(_ data: Data) {
        working = true
        Task {
            let photo = await ImageFetcher.preparedPhoto(from: data)
            working = false
            guard let photo else {
                photoError = "Couldn't read that photo"
                return
            }
            photoError = ""
            newPhoto = photo
            cover = .new
        }
    }

    private var specsSection: some View {
        FormSection(title: "Specs") {
            VStack(spacing: Space.xs) {
                ForEach($specs) { $spec in
                    HStack(spacing: Space.xs) {
                        TextField("Label", text: $spec.label).filledField()
                        TextField("Value", text: $spec.value).filledField()
                        Button {
                            let id = spec.id
                            specs.removeAll { $0.id == id }
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.circle(.flat, diameter: 36))
                        .accessibilityLabel("Remove spec")
                    }
                }
                Button {
                    specs.append(EditableSpec(label: "", value: ""))
                } label: {
                    Label("Add spec", systemImage: "plus")
                }
                .buttonStyle(.pill(.quiet, size: .small))
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func load() {
        brand = watch.brand
        model = watch.model
        reference = watch.reference
        price = PriceFormatter.editingText(pence: watch.pricePence)
        notes = watch.notes
        source = watch.sourceURLString
        specs = watch.specs.map { EditableSpec(label: $0.label, value: $0.value) }
        cover = watch.sortedPhotos.first.map { .saved($0.id) } ?? .current
    }

    private func save() async {
        working = true
        watch.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        watch.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        watch.reference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let typed = price.trimmingCharacters(in: .whitespaces)
        let newPence = PriceFormatter.pence(fromEditing: typed)
        if newPence != watch.pricePence {
            watch.pricePence = newPence
            // A hand-typed price replaces a conversion.
            if watch.originalCurrency != nil, newPence != nil { watch.priceNote = "" }
        }
        watch.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        watch.sourceURLString = source.trimmingCharacters(in: .whitespacesAndNewlines)
        watch.specs = specs
            .map { Spec(label: $0.label.trimmingCharacters(in: .whitespaces), value: $0.value.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.label.isEmpty && !$0.value.isEmpty }

        switch cover {
        case .current:
            break
        case .saved(let id):
            // Another saved photo: move it to the front.
            let photos = watch.sortedPhotos
            if id != photos.first?.id, let chosen = photos.first(where: { $0.id == id }), let data = chosen.data {
                var reordered = photos
                reordered.removeAll { $0.id == id }
                reordered.insert(chosen, at: 0)
                for (index, photo) in reordered.enumerated() { photo.index = index }
                WatchRecorder.setCover(of: watch, to: await CoverImages.encoding(data))
            }
        case .new:
            if let newPhoto {
                WatchRecorder.setCover(of: watch, to: await CoverImages.encoding(newPhoto.data))
            }
        }
        try? context.save()
        working = false
        dismiss()
    }
}
