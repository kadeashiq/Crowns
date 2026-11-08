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
        NavigationStack {
            Form {
                Section {
                    TextField("Brand", text: $brand)
                    TextField("Model", text: $model)
                    TextField("Reference", text: $reference)
                        .font(.body.monospaced())
                }
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

                Section {
                    HStack(spacing: 4) {
                        Text("£").foregroundStyle(.secondary)
                        TextField("Price", text: $price).keyboardType(.decimalPad)
                    }
                } footer: {
                    if !watch.priceNote.isEmpty { Text(watch.priceNote) }
                }

                let photos = watch.sortedPhotos
                if photos.count > 1 {
                    Section("Cover") {
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(photos) { photo in
                                    Button {
                                        coverPhotoID = photo.id
                                    } label: {
                                        DecodedImage(key: photo.id.uuidString, data: photo.data, maxPixel: 360, contentMode: .fill)
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .strokeBorder(Theme.brass, lineWidth: coverPhotoID == photo.id ? 2 : 0)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .scrollIndicators(.hidden)
                    }
                }

                Section("Specs") {
                    ForEach($specs) { $spec in
                        HStack {
                            TextField("Label", text: $spec.label)
                                .foregroundStyle(.secondary)
                            TextField("Value", text: $spec.value)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .onDelete { specs.remove(atOffsets: $0) }
                    Button("Add spec") { specs.append(EditableSpec(label: "", value: "")) }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }

                Section("Source") {
                    TextField("Link", text: $source)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.desk)
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if working {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                    }
                }
            }
        }
        .onAppear(perform: load)
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

        // A new cover: move it to the front and lift it out again.
        let photos = watch.sortedPhotos
        if let coverPhotoID, coverPhotoID != photos.first?.id, let chosen = photos.first(where: { $0.id == coverPhotoID }), let data = chosen.data {
            var reordered = photos
            reordered.removeAll { $0.id == coverPhotoID }
            reordered.insert(chosen, at: 0)
            for (index, photo) in reordered.enumerated() { photo.index = index }
            let cutout = await CutoutMaker.cutout(from: data)
            WatchRecorder.setCover(of: watch, photo: data, cutout: cutout)
        }
        try? context.save()
        working = false
        dismiss()
    }
}
