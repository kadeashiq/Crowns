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
    enum Stage: Equatable { case reading, ready, saving, saved }

    struct BoxChoice: Identifiable, Hashable {
        let id: UUID
        let name: String
    }

    var stage: Stage = .reading
    var brand = ""
    var model = ""
    var reference = ""
    var notes = ""
    /// Pounds, as typed.
    var priceText = ""
    /// "$1,650 converted", or the original price when no rate was available.
    var priceNote = ""
    var photos: [ImageFetcher.Photo] = []
    var photosLoading = true
    /// The photo in view in the carousel: the only one that gets saved.
    var visiblePhotoID: UUID?
    var boxes: [BoxChoice] = []
    var selectedBoxID: UUID?
    var errorText = ""

    let isExtension: Bool

    @ObservationIgnored private var draft = ListingDraft()
    @ObservationIgnored private var outcome: ExtractionPipeline.Outcome?
    @ObservationIgnored private var photoTask: Task<[ImageFetcher.Photo], Never>?
    @ObservationIgnored private var recorded = false
    @ObservationIgnored private var finished = false
    @ObservationIgnored var hostView: UIView?
    private let context: ModelContext
    private let onFinish: (_ savedMessage: String?) -> Void

    /// - Parameters:
    ///   - context: the store to save into.
    ///   - boxID: the box to offer first.
    ///   - finish: called when the sheet should close, with "Saved" or similar if a watch was saved.
    init(context: ModelContext, isExtension: Bool, boxID: UUID? = nil, finish: @escaping (_ savedMessage: String?) -> Void) {
        self.context = context
        self.isExtension = isExtension
        self.onFinish = finish
        loadBoxes(preferred: boxID)
    }

    var canSave: Bool { stage == .ready }

    private func loadBoxes(preferred: UUID?) {
        BoxSeeder.ensureDefaults(in: context)
        let list = BoxSeeder.orderedBoxes(in: context)
        boxes = list.map { BoxChoice(id: $0.id, name: $0.name) }
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
        reference = draft.reference
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
        }
    }

    // MARK: - Saving

    func save() async {
        guard stage == .ready else { return }
        await commit()
    }

    private func editedDraft() -> ListingDraft {
        var edited = draft
        edited.brand = brand
        edited.model = model
        edited.reference = reference
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
        let photos = await photoTask?.value ?? self.photos
        let chosen = photos.first { $0.id == visiblePhotoID } ?? photos.first
        let edited = editedDraft()
        let id = boxID
        do {
            guard let box = try context.fetch(FetchDescriptor<Box>(predicate: #Predicate { $0.id == id })).first else {
                throw CocoaError(.coderValueNotFound)
            }
            let watch = try WatchRecorder.save(edited, photos: chosen.map { [$0.data] } ?? [], coverIndex: 0, to: box, in: context)
            watch.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            try context.save()
            AppGroup.defaults.set(id.uuidString, forKey: SharedKeys.lastBoxID)
            if isExtension { ExternalChanges.markChanged() }
            draft = edited
            record(saved: true)
            Haptics.saved()
            stage = .saved
            try? await Task.sleep(for: .milliseconds(650))
            finish(isExtension ? nil : "Saved")
        } catch {
            errorText = "Couldn't save"
            stage = .ready
        }
    }

    /// The sheet was swiped away. Does nothing once a save has started.
    func cancel() {
        guard stage != .saving, stage != .saved else { return }
        photoTask?.cancel()
        record(saved: false)
        finish(nil)
    }

    private func finish(_ message: String?) {
        guard !finished else { return }
        finished = true
        onFinish(message)
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
