import Foundation

/// What we believe a page is selling, before the user saves it.
/// Every field is editable in the share sheet; none is required.
struct ListingDraft: Codable, Hashable {
    var brand: String = ""
    var model: String = ""
    var reference: String = ""
    var price: Money?
    var specs: [Spec] = []
    var imageURLs: [URL] = []
    var sourceURL: URL?
    var siteName: String = ""
    var pageTitle: String = ""
    var summary: String = ""
    var sources: Set<Source> = []

    enum Source: String, Codable, Hashable {
        case jsonLD, shopify, openGraph, microdata, pageSpecs, heuristics, linkPresentation, foundationModels
    }

    /// Missing the basics: worth trying the slower fallbacks.
    var isThin: Bool {
        (brand.isEmpty && model.isEmpty) || imageURLs.isEmpty
    }
}

struct Money: Codable, Hashable {
    var amount: Decimal
    /// ISO 4217, upper case.
    var currency: String

    var isGBP: Bool { currency == "GBP" }

    var pence: Int? {
        guard isGBP else { return nil }
        var value = amount * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }
}
