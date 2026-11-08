import SwiftUI
import SwiftData

enum ViewMode: String {
    case box, list
}

/// The box's name, chips to pick a box, and the box itself (or its list).
/// A watch opens in a sheet.
struct MainView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SyncMonitor.self) private var sync

    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]

    @AppStorage("viewMode") private var mode: ViewMode = .box
    @AppStorage("selectedBoxID") private var selectedBoxRaw = ""
    @State private var focused: Watch?
    @State private var afterDetailCloses: (() -> Void)?
    @State private var adding: AddRequest?
    @State private var editingBox: BoxEditRequest?
    @State private var showSettings = false
    @State private var showBoxOrder = false
    @State private var refreshID = UUID()
    @State private var seenStamp = ExternalChanges.stamp

    private var selectedBox: Box? {
        boxes.first { $0.id.uuidString == selectedBoxRaw } ?? boxes.first
    }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            ZStack {
                if let box = selectedBox {
                    BoxPage(
                        box: box,
                        mode: mode,
                        onOpen: open,
                        onMove: move,
                        onRemove: remove
                    )
                    // New identity per external save, to re-run queries.
                    .id("\(box.id.uuidString)|\(refreshID.uuidString)")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .simultaneousGesture(boxSwipe)
            .fadingBar(.top) {
                VStack(spacing: 0) {
                    header
                    BoxChips(
                        boxes: boxes,
                        selectedID: selectedBox?.id,
                        onSelect: select,
                        onAdd: { editingBox = BoxEditRequest(box: nil) },
                        onEdit: { editingBox = BoxEditRequest(box: $0) },
                        onReorder: { showBoxOrder = true }
                    )
                }
            }
            .fadingBar(.bottom) { addButton }
        }
        .sheet(item: $focused, onDismiss: detailClosed) { watch in
            WatchDetailView(watch: watch, onMove: move, onRemove: remove)
                .crownsSheet()
        }
        .sheet(item: $adding) { request in
            AddFlowSheet(boxID: request.boxID) { _ in
                adding = nil
            }
            .presentationDetents([.large])
            .crownsSheet()
        }
        .sheet(item: $editingBox) { request in
            BoxEditorSheet(box: request.box) { saved in
                editingBox = nil
                if let saved { select(saved) }
            }
            .crownsSheet()
        }
        .sheet(isPresented: $showBoxOrder) {
            BoxOrderSheet()
                .presentationDetents([.medium, .large])
                .crownsSheet()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .crownsSheet()
        }
        .task {
            BoxSeeder.ensureDefaults(in: context)
            normalizeSlots()
            sync.onImport = { [context] in
                BoxSeeder.mergeDuplicateSeeds(in: context)
            }
            await sync.checkAccount()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            pickUpExternalChanges()
            Task { await sync.checkAccount() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Space.xs) {
            Text(selectedBox?.name ?? " ")
                .font(Typeface.display)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: Space.xs)
            IconSegments(
                options: [
                    .init(value: ViewMode.box, icon: "square.grid.2x2.fill", label: "Grid"),
                    .init(value: ViewMode.list, icon: "list.bullet", label: "List"),
                ],
                selection: $mode
            )
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.circle())
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, Space.md)
        .padding(.top, Space.xs)
    }

    private var addButton: some View {
        Button {
            guard let box = selectedBox else { return }
            adding = AddRequest(boxID: box.id)
        } label: {
            Image(systemName: "plus")
        }
        .buttonStyle(.circle(.primary, diameter: 64))
        .accessibilityLabel("Add watch")
        .padding(.bottom, Space.xs)
    }

    // MARK: - Boxes

    private func select(_ box: Box) {
        guard box.id != selectedBox?.id else { return }
        Haptics.tick()
        selectedBoxRaw = box.id.uuidString
    }

    private var boxSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > 60, abs(dx) > abs(value.translation.height) * 1.6,
                      let current = boxes.firstIndex(where: { $0.id == selectedBox?.id }) else { return }
                let next = dx < 0 ? current + 1 : current - 1
                guard boxes.indices.contains(next) else { return }
                select(boxes[next])
            }
    }

    // MARK: - Detail

    private func open(_ watch: Watch) {
        Task {
            // Decode the large image first, so the sheet never shows an empty frame.
            if let data = watch.coverData {
                let size = WatchImage.Size.full.maxPixel
                _ = await ImageCache.shared.image(for: DecodedImage.cacheKey(watch.coverKey, size), data: data, maxPixel: size)
            }
            Haptics.lift()
            focused = watch
        }
    }

    private func detailClosed() {
        afterDetailCloses?()
        afterDetailCloses = nil
    }

    /// The detail sheet still draws its watch while it slides away, so changes
    /// to that watch wait until it has gone.
    private func applyOnceDetailCloses(_ change: @escaping () -> Void) {
        if focused != nil {
            afterDetailCloses = change
            focused = nil
        } else {
            change()
        }
    }

    private func move(_ watch: Watch, to box: Box) {
        applyOnceDetailCloses {
            let slot = box.claimFreeSlot()
            watch.box = box
            watch.slot = slot
            try? context.save()
            Haptics.saved()
        }
    }

    private func remove(_ watch: Watch) {
        applyOnceDetailCloses {
            context.delete(watch)
            try? context.save()
            Haptics.settle()
        }
    }

    // MARK: - Housekeeping

    /// The extension writes from another process. Re-running the queries
    /// makes its inserts appear without relaunching.
    private func pickUpExternalChanges() {
        let stamp = ExternalChanges.stamp
        guard stamp > seenStamp else { return }
        seenStamp = stamp
        BoxSeeder.mergeDuplicateSeeds(in: context)
        normalizeSlots()
        refreshID = UUID()
    }

    /// Two devices can put watches in the same slot before syncing.
    private func normalizeSlots() {
        var changed = false
        for box in boxes {
            let slots = (box.watches ?? []).map(\.slot)
            if Set(slots).count != slots.count || slots.contains(where: { $0 >= box.capacity }) {
                box.compactSlots()
                changed = true
            }
        }
        if changed { try? context.save() }
    }
}

struct AddRequest: Identifiable {
    let id = UUID()
    let boxID: UUID
}

struct BoxEditRequest: Identifiable {
    let id = UUID()
    let box: Box?
}
