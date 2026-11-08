import SwiftUI
import SwiftData

enum ViewMode: String {
    case box, list
}

/// Chips to pick a box, the box itself (or its list), and the detail view
/// that a watch lifts into.
struct MainView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ToastCenter.self) private var toast
    @Environment(SyncMonitor.self) private var sync
    @Environment(ProStore.self) private var store

    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]

    @AppStorage("viewMode") private var mode: ViewMode = .box
    @AppStorage("selectedBoxID") private var selectedBoxRaw = ""
    @State private var direction: CGFloat = 1
    @State private var focused: Watch?
    @State private var adding: AddRequest?
    @State private var editingBox: BoxEditRequest?
    @State private var showSettings = false
    @State private var pending: PendingRequest?
    @State private var refreshID = UUID()
    @State private var seenStamp = ExternalChanges.stamp
    @Namespace private var hero

    private var selectedBox: Box? {
        boxes.first { $0.id.uuidString == selectedBoxRaw } ?? boxes.first
    }

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    BoxChips(
                        boxes: boxes,
                        selectedID: selectedBox?.id,
                        onSelect: select,
                        onAdd: { editingBox = BoxEditRequest(box: nil) },
                        onEdit: { editingBox = BoxEditRequest(box: $0) }
                    )
                    .padding(.vertical, 8)

                    ZStack {
                        if let box = selectedBox {
                            BoxPage(
                                box: box,
                                mode: mode,
                                hero: hero,
                                focusedID: focused?.id,
                                onOpen: open,
                                onAdd: { slot in adding = AddRequest(boxID: box.id, slot: slot) },
                                onMove: move,
                                onRemove: remove
                            )
                            // New identity per box (for the switch transition) and per
                            // external save (to re-run queries).
                            .id("\(box.id.uuidString)|\(refreshID.uuidString)")
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(x: 26 * direction)),
                                removal: .opacity.combined(with: .offset(x: -26 * direction))
                            ))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .simultaneousGesture(boxSwipe)
                }
                .background(Theme.deskBackground)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        modeToggle
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            }

            if let focused {
                WatchDetailView(watch: focused, hero: hero, onClose: close, onMove: move, onRemove: remove)
                    .zIndex(2)
                    .transition(.opacity)
            }

            ToastOverlay(center: toast)
                .zIndex(3)
        }
        .sheet(item: $adding) { request in
            AddFlowSheet(boxID: request.boxID, slot: request.slot) { message in
                adding = nil
                if let message { toast.show(message) }
            }
            .presentationDetents([.large])
            .presentationBackground(Theme.desk)
        }
        .sheet(item: $editingBox) { request in
            BoxEditorSheet(box: request.box) { saved in
                editingBox = nil
                if let saved { select(saved) }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(item: $pending) { request in
            PendingSaveSheet(request: request) { saved in
                pending = nil
                if saved { toast.show("Saved") }
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            BoxSeeder.ensureDefaults(in: context)
            normalizeSlots()
            sync.onImport = { [context] in
                BoxSeeder.mergeDuplicateSeeds(in: context)
            }
            await store.load()
            await sync.checkAccount()
            checkPending()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            pickUpExternalChanges()
            checkPending()
            Task { await sync.checkAccount() }
        }
    }

    // MARK: - Mode

    private var modeToggle: some View {
        Picker("View", selection: $mode.animation(Motion.standard)) {
            Image(systemName: "square.grid.2x2")
                .accessibilityLabel("Box")
                .tag(ViewMode.box)
            Image(systemName: "list.bullet")
                .accessibilityLabel("List")
                .tag(ViewMode.list)
        }
        .pickerStyle(.segmented)
        .frame(width: 104)
    }

    // MARK: - Boxes

    private func select(_ box: Box) {
        guard box.id != selectedBox?.id else { return }
        let from = boxes.firstIndex { $0.id == selectedBox?.id } ?? 0
        let to = boxes.firstIndex { $0.id == box.id } ?? 0
        direction = to >= from ? 1 : -1
        Haptics.tick()
        withAnimation(Motion.boxSwitch) {
            selectedBoxRaw = box.id.uuidString
        }
    }

    private var boxSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                guard focused == nil, abs(dx) > 60, abs(dx) > abs(value.translation.height) * 1.6,
                      let current = boxes.firstIndex(where: { $0.id == selectedBox?.id }) else { return }
                let next = dx < 0 ? current + 1 : current - 1
                guard boxes.indices.contains(next) else { return }
                select(boxes[next])
            }
    }

    // MARK: - Detail

    private func open(_ watch: Watch) {
        Task {
            // Decode the large image before anything moves, so the lift
            // never shows an empty frame.
            if let data = watch.coverData {
                _ = await ImageCache.shared.image(for: DecodedImage.cacheKey(watch.coverKey, WatchHeadMetrics.maxPixel), data: data, maxPixel: WatchHeadMetrics.maxPixel)
            }
            Haptics.lift()
            withAnimation(Motion.lift) { focused = watch }
        }
    }

    private func close() {
        withAnimation(Motion.settle) {
            focused = nil
        } completion: {
            Haptics.settle()
        }
    }

    private func move(_ watch: Watch, to box: Box) {
        let slot = box.claimFreeSlot()
        let apply = {
            watch.box = box
            watch.slot = slot
            try? context.save()
            toast.show("Moved to \(box.name)")
        }
        if focused != nil {
            withAnimation(Motion.settle) { focused = nil } completion: { apply() }
        } else {
            withAnimation(Motion.standard) { apply() }
        }
    }

    private func remove(_ watch: Watch) {
        let apply = {
            context.delete(watch)
            try? context.save()
            toast.show("Removed")
        }
        if focused != nil {
            withAnimation(Motion.settle) { focused = nil } completion: { apply() }
        } else {
            withAnimation(Motion.standard) { apply() }
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

    /// Two devices can put watches on the same cushion before syncing.
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

    private func checkPending() {
        guard pending == nil, PendingSaveStore.load() != nil else { return }
        pending = PendingRequest()
    }
}

struct AddRequest: Identifiable {
    let id = UUID()
    let boxID: UUID
    let slot: Int?
}

struct BoxEditRequest: Identifiable {
    let id = UUID()
    let box: Box?
}

struct PendingRequest: Identifiable {
    let id = UUID()
}
