import Foundation

/// Raw facts read from a web page by Preprocess.js. Every field is optional:
/// the extractor reports what it found and nothing more.
struct PageSnapshot: Codable, Hashable {
    var v: Int?
    var url: String?
    var canonical: String?
    var title: String?
    var lang: String?
    var h1: String?
    var meta: [String: String]?
    var metaImages: [String]?
    var jsonld: [JSONValue]?
    var shopify: JSONValue?
    var microdata: [String: String]?
    var specs: [[String]]?
    var priceTexts: [String]?
    var images: [Image]?
    var text: String?
    var errors: [String]?

    struct Image: Codable, Hashable {
        var src: String
        var w: Int?
        var h: Int?
        var alt: String?
    }

    static func decode(_ json: String) -> PageSnapshot? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PageSnapshot.self, from: data)
    }

    /// True when the page carries product data we can trust more than text.
    var hasStructuredData: Bool {
        if !(jsonld ?? []).isEmpty { return true }
        if let shopify, shopify.isObject { return true }
        let m = meta ?? [:]
        return m["product:price:amount"] != nil || m["og:price:amount"] != nil
    }

    var pageURL: URL? {
        url.flatMap(URL.init(string:))
    }
}
