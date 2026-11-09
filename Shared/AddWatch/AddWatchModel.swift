import Foundation
import SwiftData
import UIKit

/// What a new watch starts from.
enum AddWatchSource {
    /// From the share sheet: Safari's snapshot and/or a URL.
    case share(ShareInput)
    /// A link pasted in the app.
    case link(URL)
    /// Typed in by hand in the app.
    case manual
}

struct ShareInput {
    /// JSON from Preprocess.js, present when shared from Safari.
    var snapshotJSON: String?
    /// The page URL. From Safari alongside the snapshot; from other apps alone.
    var url: URL?
}

/// One spec in the form. Parsed and standard specs keep their label;
/// `isCustom` ones have a label the user types.
struct EditableSpec: Identifiable {
    let id = UUID()
    var label: String
    var value: String
    var isCustom = false

    /// What was parsed, plus the standard fields it didn't fill, in the usual order.
    static func merging(_ parsed: [Spec]) -> [EditableSpec] {
        let blanks = SpecNormalizer.formFields
            .filter { field in !parsed.contains { $0.label == field } }
            .map { Spec(label: $0, value: "") }
        return SpecNormalizer.ordered(parsed + blanks).map { EditableSpec(label: $0.label, value: $0.value) }
    }

    /// The specs worth keeping: filled in, and one per label.
    static func saved(_ specs: [EditableSpec]) -> [Spec] {
        var seen = Set<String>()
        let filled = specs.compactMap { spec -> Spec? in
            let label = spec.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = spec.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty, !value.isEmpty, seen.insert(label.lowercased()).inserted else { return nil }
            return Spec(label: label, value: value)
        }
        return SpecNormalizer.ordered(filled)
    }
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
    var specs = EditableSpec.merging([])
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
    /// Being added by hand rather than read from a page.
    var isManual = false
    /// The camera is up. The sheet behind it mustn't count as closed.
    var isTakingPhoto = false
    /// The slower readers are still going through the page.
    private var isEnriching = false

    let isExtension: Bool

    @ObservationIgnored private var draft = ListingDraft()
    /// What the readers had last reported, to tell new findings from old ones.
    @ObservationIgnored private var lastFound = ListingDraft()
    @ObservationIgnored private var startTask: Task<Void, Never>?
    @ObservationIgnored private var photoTask: Task<Void, Never>?
    @ObservationIgnored private var enrichTask: Task<Void, Never>?
    @ObservationIgnored private var priceTask: Task<Void, Never>?
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

    /// From a page, the first photo is enough: the rest are only alternatives.
    var canSave: Bool {
        guard stage == .ready else { return false }
        if isManual { return !photosLoading && hasDetails }
        return !photosLoading || !photos.isEmpty
    }

    private var hasDetails: Bool {
        !photos.isEmpty || !brand.trimmingCharacters(in: .whitespaces).isEmpty || !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// What's being pulled from the page right now, or nil once it's done.
    var loadingMessage: String? {
        if stage == .reading { return "Reading listing…" }
        if photosLoading { return "Getting photos…" }
        if isEnriching, photos.isEmpty, brand.isEmpty, model.isEmpty { return "Reading listing…" }
        return nil
    }

    /// The page gave us nothing to work with.
    var foundNothing: Bool {
        !isManual && loadingMessage == nil && photos.isEmpty && brand.isEmpty && model.isEmpty
    }

    private func loadBoxes(preferred: UUID?) {
        BoxSeeder.ensureDefaults(in: context, merging: !isExtension)
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

    func start(_ source: AddWatchSource) {
        guard !finished else { return }
        switch source {
        case .share(let input):
            startTask = Task { await read(snapshotJSON: input.snapshotJSON, url: input.url) }
        case .link(let url):
            startTask = Task { await read(snapshotJSON: nil, url: url) }
        case .manual:
            isManual = true
            stage = .ready
            photosLoading = false
        }
    }

    /// Uses this photo for a watch added by hand.
    func setPhoto(_ data: Data) {
        photosLoading = true
        Task {
            let photo = await ImageFetcher.preparedPhoto(from: data)
            photosLoading = false
            guard let photo else {
                errorText = "Couldn't read that photo"
                return
            }
            errorText = ""
            photos = [photo]
            visiblePhotoID = photo.id
        }
    }

    /// Specs the form doesn't already show, to offer under Add spec.
    var unusedSpecLabels: [String] {
        SpecNormalizer.labels.filter { label in !specs.contains { $0.label == label } }
    }

    func addSpec(_ label: String?) {
        specs.append(EditableSpec(label: label ?? "", value: "", isCustom: label == nil))
    }

    /// Fills in a suggestion. A brand on its own leaves any model typed so far.
    func apply(_ match: WatchCatalog.Match) {
        Haptics.tick()
        brand = match.brand
        if !match.model.isEmpty { model = match.model }
    }

    private func read(snapshotJSON: String?, url: URL?) async {
        FoundationModelsFallback.prewarm()
        let snapshot = snapshotJSON.flatMap(PageSnapshot.decode)
        if snapshot == nil {
            // Let the sheet's anchor view appear so the web reader has a window.
            for _ in 0..<10 where hostView == nil {
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
        let reading = await ExtractionPipeline.read(snapshot: snapshot, url: url, host: hostView)
        guard !Task.isCancelled else { return }
        draft = reading.draft
        lastFound = reading.draft
        brand = draft.brand
        model = draft.model
        reference = draft.reference
        priceText = PriceFormatter.editingText(pence: draft.price?.pence)
        specs = EditableSpec.merging(draft.specs)
        stage = .ready
        convertPrice()

        let linkPreview = reading.needsLinkPreview ? reading.draft.sourceURL.map { link in
            Task { await LinkPreviewFallback.fetch(link) }
        } : nil
        let urls = draft.imageURLs
        let referer = draft.sourceURL
        photoTask = Task {
            await ImageFetcher.photos(from: urls, referer: referer) { [weak self] photo in
                self?.add(photo)
            }
            if photos.isEmpty, let extra = await linkPreview?.value?.imageData,
               let photo = await ImageFetcher.preparedPhoto(from: extra) {
                add(photo)
            }
            photosLoading = false
        }
        isEnriching = true
        enrichTask = Task {
            await ExtractionPipeline.enrich(reading, preview: await linkPreview?.value) { [weak self] found in
                self?.merge(found)
            }
            isEnriching = false
        }
    }

    /// Photos only ever join the end, so the one in view never moves.
    private func add(_ photo: ImageFetcher.Photo) {
        photos.append(photo)
        if visiblePhotoID == nil {
            visiblePhotoID = photo.id
        }
    }

    /// Takes what a slower reader found. The form is open by now, so only
    /// new findings count, and they only go into fields that are still empty:
    /// nothing typed is replaced and nothing cleared comes back.
    func merge(_ found: ListingDraft) {
        let before = lastFound
        lastFound = found
        if found.brand != before.brand, brand.isEmpty { brand = found.brand }
        if found.model != before.model, model.isEmpty { model = found.model }
        if found.reference != before.reference, reference.isEmpty { reference = found.reference }
        for spec in found.specs where !before.specs.contains(spec) {
            if let index = specs.firstIndex(where: { $0.label == spec.label }) {
                if specs[index].value.isEmpty { specs[index].value = spec.value }
            } else {
                specs.append(EditableSpec(label: spec.label, value: spec.value))
            }
        }
        if draft.price == nil, let price = found.price {
            draft.price = price
            if priceText.isEmpty { priceText = PriceFormatter.editingText(pence: price.pence) }
            convertPrice()
        }
    }

    /// Prices are always pounds. A foreign one stays out of the field until
    /// it has been converted, so nothing but pounds is ever shown as pounds.
    private func convertPrice() {
        priceNote = draft.priceNote
        guard let price = draft.price, !price.isGBP else { return }
        priceNote = ""
        priceTask = Task {
            let converted = await CurrencyConverter.toGBP(price)
            guard !Task.isCancelled else { return }
            if let converted {
                draft.originalPrice = price
                draft.price = converted
                if priceText.isEmpty { priceText = PriceFormatter.editingText(pence: converted.pence) }
            }
            priceNote = draft.priceNote
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
        edited.specs = EditableSpec.saved(specs)
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
        // What's on screen is what gets saved, so stop looking for more.
        photoTask?.cancel()
        enrichTask?.cancel()
        await priceTask?.value
        let chosen = photos.first { $0.id == visiblePhotoID } ?? photos.first
        let cover = await CoverImages.encoding(chosen?.data)
        let edited = editedDraft()
        let id = boxID
        do {
            guard let box = try context.fetch(FetchDescriptor<Box>(predicate: #Predicate { $0.id == id })).first else {
                throw CocoaError(.coderValueNotFound)
            }
            try WatchRecorder.save(edited, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), cover: cover, to: box, in: context)
            AppGroup.defaults.set(id.uuidString, forKey: SharedKeys.lastBoxID)
            if isExtension { ExternalChanges.markChanged() }
            draft = edited
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
        guard stage != .saving, stage != .saved, !isTakingPhoto else { return }
        stop()
        finish(nil)
    }

    /// Stops any work in progress and leaves the sheet as it is.
    func stop() {
        // A save in progress is still waiting on its price.
        guard stage != .saving else { return }
        startTask?.cancel()
        photoTask?.cancel()
        enrichTask?.cancel()
        priceTask?.cancel()
    }

    private func finish(_ message: String?) {
        guard !finished else { return }
        finished = true
        onFinish(message)
    }
}
