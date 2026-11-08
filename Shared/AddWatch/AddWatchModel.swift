import Foundation
import SwiftData
import UIKit

/// What a new watch starts from.
enum AddWatchSource {
    /// From the share sheet: Safari's snapshot and/or a URL.
    case share(ShareInput)
    /// A link pasted in the app.
    case link(URL)
    /// A photo picked in the app.
    case photo(Data)
}

struct ShareInput {
    /// JSON from Preprocess.js, present when shared from Safari.
    var snapshotJSON: String?
    /// The page URL. From Safari alongside the snapshot; from other apps alone.
    var url: URL?
}

/// Drives the add-watch sheet, in the share extension and in the app.
@MainActor
@Observable
final class AddWatchModel {
    enum Stage: Equatable { case reading, ready, saving, saved, paywall, handedOff }

    struct BoxChoice: Identifiable, Hashable {
        let id: UUID
        let name: String
        let finish: BoxFinish
    }

    var stage: Stage = .reading
    var brand = ""
    var model = ""
    /// Pounds, as typed.
    var priceText = ""
    /// "$1,650 converted", or the original price when no rate was available.
    var priceNote = ""
    var photos: [ImageFetcher.Photo] = []
    var photosLoading = true
    /// The photo in view in the carousel, which is the cover.
    /// The sheet calls `coverChanged()` when this changes.
    var visiblePhotoID: UUID?
    /// Cut-outs of photos, keyed by photo id, ready to draw.
    var cutouts: [UUID: UIImage] = [:]
    var boxes: [BoxChoice] = []
    var selectedBoxID: UUID?
    var errorText = ""

    let isExtension: Bool
    let store = ProStore.shared

    @ObservationIgnored private var draft = ListingDraft()
    @ObservationIgnored private var outcome: ExtractionPipeline.Outcome?
    @ObservationIgnored private var photoTask: Task<[ImageFetcher.Photo], Never>?
    @ObservationIgnored private var cutoutTask: Task<Void, Never>?
    @ObservationIgnored private var cutoutData: [UUID: Data] = [:]
    @ObservationIgnored private var cutoutFailed: Set<UUID> = []
    @ObservationIgnored private var preferredSlot: Int?
    @ObservationIgnored private var preferredBoxID: UUID?
    @ObservationIgnored private var recorded = false
    @ObservationIgnored var hostView: UIView?
    private let context: ModelContext
    private let onFinish: (_ savedMessage: String?) -> Void

    /// - Parameters:
    ///   - context: the store to save into.
    ///   - boxID, slot: where to put the watch when adding from a cushion.
    ///   - finish: called when the sheet should close, with "Saved" or similar if a watch was saved.
    init(context: ModelContext, isExtension: Bool, boxID: UUID? = nil, slot: Int? = nil, finish: @escaping (_ savedMessage: String?) -> Void) {
        self.context = context
        self.isExtension = isExtension
        self.preferredSlot = slot
        self.preferredBoxID = boxID
        self.onFinish = finish
        loadBoxes(preferred: boxID)
    }

    var coverIndex: Int {
        photos.firstIndex { $0.id == visiblePhotoID } ?? 0
    }

    var canSave: Bool { stage == .ready }

    var selectedFinish: BoxFinish {
        boxes.first { $0.id == selectedBoxID }?.finish ?? .walnut
    }

    private func loadBoxes(preferred: UUID?) {
        BoxSeeder.ensureDefaults(in: context)
        let list = BoxSeeder.orderedBoxes(in: context)
        boxes = list.map { BoxChoice(id: $0.id, name: $0.name, finish: $0.finish) }
        let last = AppGroup.defaults.string(forKey: SharedKeys.lastBoxID).flatMap(UUID.init(uuidString:))
        // From a shop page it's usually a want, so the very first save goes to Wishlist.
        selectedBoxID = boxes.first(where: { $0.id == preferred })?.id
            ?? boxes.first(where: { $0.id == last })?.id
            ?? list.first(where: { $0.seedKey == BoxSeeder.wishlistKey })?.id
            ?? boxes.first?.id
    }

    // MARK: - Reading

    func start(_ source: AddWatchSource) async {
        // Let the sheet's anchor view appear so the web reader has a window.
        for _ in 0..<10 where hostView == nil {
            try? await Task.sleep(for: .milliseconds(30))
        }
        switch source {
        case .share(let input):
            await read(snapshotJSON: input.snapshotJSON, url: input.url)
        case .link(let url):
            await read(snapshotJSON: nil, url: url)
        case .photo(let data):
            stage = .ready
            if let photo = ImageFetcher.photo(from: data) {
                photos = [photo]
                visiblePhotoID = photo.id
                coverChanged()
            } else {
                errorText = "Couldn't read that photo"
            }
            photosLoading = false
        }
    }

    private func read(snapshotJSON: String?, url: URL?) async {
        let outcome = await ExtractionPipeline.run(snapshotJSON: snapshotJSON, url: url, host: hostView)
        self.outcome = outcome
        draft = outcome.draft
        brand = draft.brand
        model = draft.model
        priceText = PriceFormatter.editingText(pence: draft.price?.pence)
        priceNote = draft.priceNote
        stage = .ready

        let urls = draft.imageURLs
        let referer = draft.sourceURL
        let extra = outcome.extraImage
        let task = Task { () -> [ImageFetcher.Photo] in
            var photos = await ImageFetcher.photos(from: urls, referer: referer)
            if photos.isEmpty, let extra, let photo = ImageFetcher.photo(from: extra) {
                photos = [photo]
            }
            return photos
        }
        photoTask = task
        let loaded = await task.value
        photos = loaded
        photosLoading = false
        if visiblePhotoID == nil {
            visiblePhotoID = loaded.first?.id
            coverChanged()
        }
    }

    // MARK: - Cut-outs

    func coverChanged() {
        cutoutTask?.cancel()
        guard let id = visiblePhotoID, let photo = photos.first(where: { $0.id == id }),
              cutouts[id] == nil, !cutoutFailed.contains(id) else { return }
        cutoutTask = Task { [weak self] in
            // Let a quick swipe settle before spending time on Vision.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let png = await CutoutMaker.cutout(from: photo.data)
            guard let self, !Task.isCancelled else { return }
            guard let png, let cg = ImageDownscaler.thumbnail(from: png, maxPixel: ImageFetcher.previewPixel) else {
                self.cutoutFailed.insert(id)
                return
            }
            self.cutoutData[id] = png
            self.cutouts[id] = UIImage(cgImage: cg)
            self.trimCutouts(keeping: id)
        }
    }

    /// Keeps memory flat in the extension: only the last few cut-outs stay.
    private func trimCutouts(keeping id: UUID) {
        guard cutouts.count > 3 else { return }
        for key in cutouts.keys where key != id && cutouts.count > 3 {
            cutouts[key] = nil
            cutoutData[key] = nil
        }
    }

    // MARK: - Saving

    func save() async {
        guard stage == .ready else { return }
        guard store.canAddWatch(in: context) else {
            stage = .paywall
            return
        }
        await commit()
    }

    /// After the paywall: true means Pro is now active.
    func paywallFinished(_ subscribed: Bool) async {
        if subscribed {
            stage = .ready
            await commit()
        } else {
            stage = .ready
        }
    }

    /// The extension can't always complete a purchase. Hand the watch to the
    /// app, which shows the paywall next time it opens and then saves it.
    func handOffToApp() async {
        let photos = await photoTask?.value ?? self.photos
        PendingSaveStore.stash(editedDraft(), photos: photos.map(\.data), coverIndex: coverIndex, cutout: currentCutout, boxID: selectedBoxID)
        record(saved: false)
        stage = .handedOff
    }

    private var currentCutout: Data? {
        visiblePhotoID.flatMap { cutoutData[$0] }
    }

    private func editedDraft() -> ListingDraft {
        var edited = draft
        edited.brand = brand
        edited.model = model
        let typed = priceText.trimmingCharacters(in: .whitespaces)
        if let pence = PriceFormatter.pence(fromEditing: typed) {
            if pence != draft.price?.pence {
                // A price typed by hand replaces any conversion.
                edited.price = Money(amount: Decimal(pence) / 100, currency: "GBP")
                if draft.price?.isGBP == true || draft.price == nil { edited.originalPrice = nil }
            }
        } else if typed.isEmpty, draft.price?.isGBP == true {
            edited.price = nil
            edited.originalPrice = nil
        }
        return edited
    }

    private func commit() async {
        guard let boxID = selectedBoxID else { return }
        stage = .saving
        // If the cover's cut-out is still running, give it a moment to land.
        if let id = visiblePhotoID, cutoutData[id] == nil, !cutoutFailed.contains(id) {
            _ = await cutoutTask?.value
        }
        let photos = await photoTask?.value ?? self.photos
        let edited = editedDraft()
        let id = boxID
        do {
            guard let box = try context.fetch(FetchDescriptor<Box>(predicate: #Predicate { $0.id == id })).first else {
                throw CocoaError(.coderValueNotFound)
            }
            // The tapped cushion only counts if they kept the box it was in.
            let slot = boxID == preferredBoxID ? preferredSlot : nil
            try WatchRecorder.save(edited, photos: photos.map(\.data), coverIndex: coverIndex, coverCutout: currentCutout, to: box, slot: slot, in: context)
            AppGroup.defaults.set(id.uuidString, forKey: SharedKeys.lastBoxID)
            if isExtension { ExternalChanges.markChanged() }
            draft = edited
            record(saved: true)
            Haptics.saved()
            stage = .saved
            try? await Task.sleep(for: .milliseconds(650))
            onFinish(isExtension ? nil : "Saved")
        } catch {
            errorText = "Couldn't save"
            stage = .ready
        }
    }

    func cancel() {
        photoTask?.cancel()
        cutoutTask?.cancel()
        record(saved: false)
        onFinish(nil)
    }

    func close() {
        onFinish(nil)
    }

    private func record(saved: Bool) {
        guard !recorded, outcome != nil else { return }
        recorded = true
        DiagnosticsLog.record(DiagnosticEntry(
            url: draft.sourceURL?.absoluteString,
            steps: outcome?.steps ?? [],
            draft: draft,
            photoCount: photos.count,
            saved: saved,
            snapshotJSON: outcome?.snapshotJSON
        ))
    }
}
