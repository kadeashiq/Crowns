import Foundation
import SwiftData
import UIKit
import Observation

@MainActor
@Observable
final class ShareModel {
    enum Stage: Equatable { case reading, ready, saving, saved, failed }

    struct BoxChoice: Identifiable, Hashable {
        let id: UUID
        let name: String
    }

    var stage: Stage = .reading
    var brand = ""
    var model = ""
    /// Pounds, as typed. Empty for listings in other currencies until phase 4 converts them.
    var priceText = ""
    /// The listing's own price when it wasn't in pounds, e.g. "$4,250".
    var priceNote = ""
    var photos: [ImageFetcher.Photo] = []
    var photosLoading = true
    var coverIndex = 0
    var boxes: [BoxChoice] = []
    var selectedBoxID: UUID?
    var errorText = ""

    @ObservationIgnored private var draft = ListingDraft()
    @ObservationIgnored private var outcome: ExtractionPipeline.Outcome?
    @ObservationIgnored private var photoTask: Task<[ImageFetcher.Photo], Never>?
    private let container: ModelContainer
    private let onFinish: () -> Void
    private let onCancel: () -> Void
    @ObservationIgnored private var recorded = false

    init(finish: @escaping () -> Void, cancel: @escaping () -> Void) {
        container = SharedStore.extensionContainer()
        onFinish = finish
        onCancel = cancel
        loadBoxes()
    }

    private func loadBoxes() {
        let context = container.mainContext
        BoxSeeder.ensureDefaults(in: context)
        let list = BoxSeeder.orderedBoxes(in: context)
        boxes = list.map { BoxChoice(id: $0.id, name: $0.name) }
        let last = AppGroup.defaults.string(forKey: SharedKeys.lastBoxID).flatMap(UUID.init(uuidString:))
        // First save defaults to Wishlist: from a shop page, it's usually a want.
        selectedBoxID = boxes.first(where: { $0.id == last })?.id
            ?? list.first(where: { $0.seedKey == BoxSeeder.wishlistKey })?.id
            ?? boxes.first?.id
    }

    func start(input: ShareInput, host: UIView) async {
        let outcome = await ExtractionPipeline.run(snapshotJSON: input.snapshotJSON, url: input.url, host: host)
        self.outcome = outcome
        draft = outcome.draft
        brand = draft.brand
        model = draft.model
        if let price = draft.price {
            if price.isGBP {
                priceText = PriceFormatter.editingText(pence: price.pence)
            } else {
                priceNote = PriceFormatter.original(price)
            }
        }
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
    }

    func save() async {
        guard stage == .ready, let boxID = selectedBoxID else { return }
        stage = .saving

        var edited = draft
        edited.brand = brand
        edited.model = model
        let typed = priceText.trimmingCharacters(in: .whitespaces)
        if let pence = PriceFormatter.pence(fromEditing: typed) {
            edited.price = Money(amount: Decimal(pence) / 100, currency: "GBP")
        } else if typed.isEmpty, draft.price?.isGBP == true {
            edited.price = nil
        }

        let photos = await photoTask?.value ?? self.photos
        let context = container.mainContext
        let id = boxID
        do {
            guard let box = try context.fetch(FetchDescriptor<Box>(predicate: #Predicate { $0.id == id })).first else {
                throw CocoaError(.coderValueNotFound)
            }
            try WatchRecorder.save(edited, photos: photos, coverIndex: coverIndex, to: box, in: context)
            AppGroup.defaults.set(id.uuidString, forKey: SharedKeys.lastBoxID)
            ExternalChanges.markChanged()
            record(saved: true, draft: edited, photoCount: photos.count)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            stage = .saved
            try? await Task.sleep(for: .milliseconds(700))
            onFinish()
        } catch {
            errorText = "Couldn't save"
            stage = .ready
        }
    }

    func cancel() {
        photoTask?.cancel()
        record(saved: false, draft: draft, photoCount: photos.count)
        onCancel()
    }

    private func record(saved: Bool, draft: ListingDraft, photoCount: Int) {
        guard !recorded else { return }
        recorded = true
        DiagnosticsLog.record(DiagnosticEntry(
            url: draft.sourceURL?.absoluteString,
            steps: outcome?.steps ?? [],
            draft: draft,
            photoCount: photoCount,
            saved: saved,
            snapshotJSON: outcome?.snapshotJSON
        ))
    }
}
