import SwiftUI
import SwiftData

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
    @State private var coverPhotoID: UUID?
    @State private var working = false

    private struct EditableSpec: Identifiable {
        let id = UUID()
        var label: String
        var value: String
    }

    var body: some View {

        ScrollView {
            VStack(spacing: Space.lg) {
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

                let photos = watch.sortedPhotos
                if photos.count > 1 {
                    coverPicker(photos)
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

    private func coverPicker(_ photos: [WatchPhoto]) -> some View {
        FormSection(title: "Cover") {
            ScrollView(.horizontal) {
                HStack(spacing: Space.sm) {
                    ForEach(photos) { photo in
                        let selected = coverPhotoID == photo.id
                        Button {
                            Haptics.tick()
                            coverPhotoID = photo.id
                        } label: {
                            DecodedImage(key: photo.id.uuidString, data: photo.data, maxPixel: 360, contentMode: .fill)
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                                .padding(3)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.sm + 3, style: .continuous)
                                        .strokeBorder(Theme.ink, lineWidth: selected ? 2 : 0)
                                )
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .scrollIndicators(.hidden)
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
        coverPhotoID = watch.sortedPhotos.first?.id
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

        // A new cover: move it to the front.
        let photos = watch.sortedPhotos
        if let coverPhotoID, coverPhotoID != photos.first?.id, let chosen = photos.first(where: { $0.id == coverPhotoID }), let data = chosen.data {
            var reordered = photos
            reordered.removeAll { $0.id == coverPhotoID }
            reordered.insert(chosen, at: 0)
            for (index, photo) in reordered.enumerated() { photo.index = index }
            WatchRecorder.setCover(of: watch, photo: data)
        }
        try? context.save()
        working = false
        dismiss()
    }
}
