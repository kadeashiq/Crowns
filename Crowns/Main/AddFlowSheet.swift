import SwiftUI
import SwiftData
import PhotosUI

/// Adding inside the app: paste a link (same reader as the share extension)
/// or pick a photo, then the same compact sheet.
struct AddFlowSheet: View {
    let boxID: UUID?
    let onDone: (String?) -> Void

    @Environment(\.modelContext) private var context
    @State private var model: AddWatchModel?
    @State private var photoItem: PhotosPickerItem?
    @State private var note = ""

    var body: some View {
        if let model {
            AddWatchSheet(model: model)
                .onDisappear { model.cancel() }
        } else {
            chooser
        }
    }

    private var chooser: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Add a watch")
                .font(Typeface.title)
                .foregroundStyle(Theme.ink)
            Text("Paste a link from any shop, or choose a photo.")
                .font(Typeface.secondary)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, Space.xxs)
            Spacer()

            VStack(spacing: Space.sm) {
                PasteButton(supportedContentTypes: [.url, .plainText]) { providers in
                    Task { @MainActor in
                        if let url = await ShareInputReader.firstURL(from: providers) {
                            begin(.link(url))
                        } else {
                            note = "No link to paste"
                        }
                    }
                }
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(Theme.ink)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Choose photo", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill(.secondary))

                if !note.isEmpty {
                    Text(note)
                        .font(Typeface.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.lg)
        }
        .background(Theme.canvas)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                let loaded = try? await item.loadTransferable(type: Data.self)
                if let data = loaded ?? nil {
                    begin(.photo(data))
                } else {
                    note = "Couldn't read that photo"
                }
            }
        }
    }

    private func begin(_ source: AddWatchSource) {
        let model = AddWatchModel(context: context, isExtension: false, boxID: boxID, finish: onDone)
        self.model = model
        Task { await model.start(source) }
    }
}
