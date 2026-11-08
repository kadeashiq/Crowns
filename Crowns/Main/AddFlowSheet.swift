import SwiftUI
import SwiftData
import PhotosUI

/// Adding inside the app: paste a link (same reader as the share extension)
/// or pick a photo, then the same compact sheet.
struct AddFlowSheet: View {
    let boxID: UUID?
    let slot: Int?
    let onDone: (String?) -> Void

    @Environment(\.modelContext) private var context
    @State private var model: AddWatchModel?
    @State private var photoItem: PhotosPickerItem?
    @State private var note = ""

    var body: some View {
        ZStack {
            if let model {
                AddWatchSheet(model: model)
                    .transition(.opacity)
            } else {
                chooser
                    .transition(.opacity)
            }
        }
        .animation(Motion.standard, value: model == nil)
    }

    private var chooser: some View {
        ZStack {
            Theme.deskBackground
            VStack(spacing: 14) {
                HStack {
                    Button {
                        onDone(nil)
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
                Spacer()
                Text("Add watch")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 10)
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
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Choose photo", systemImage: "photo")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                if !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                Spacer()
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
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
        let model = AddWatchModel(context: context, isExtension: false, boxID: boxID, slot: slot, finish: onDone)
        self.model = model
        Task { await model.start(source) }
    }
}

/// A watch the share extension handed over because it couldn't take payment.
struct PendingSaveSheet: View {
    let request: PendingRequest
    let onDone: (Bool) -> Void

    @Environment(\.modelContext) private var context
    @Environment(ProStore.self) private var store

    var body: some View {
        ZStack {
            Theme.deskBackground
            ScrollView {
                PaywallView(store: store) { subscribed in
                    if subscribed { commit() } else { PendingSaveStore.clear(); onDone(false) }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            // Already Pro, or under the limit after all: just save it.
            await store.refresh()
            if store.canAddWatch(in: context) { commit() }
        }
    }

    private func commit() {
        guard let loaded = PendingSaveStore.load() else {
            onDone(false)
            return
        }
        let pending = loaded.pending
        let boxes = BoxSeeder.orderedBoxes(in: context)
        guard let box = boxes.first(where: { $0.id == pending.boxID }) ?? boxes.first else {
            onDone(false)
            return
        }
        let saved = (try? WatchRecorder.save(pending.draft, photos: loaded.photos, coverIndex: pending.coverIndex, coverCutout: loaded.cutout, to: box, in: context)) != nil
        PendingSaveStore.clear()
        onDone(saved)
    }
}
