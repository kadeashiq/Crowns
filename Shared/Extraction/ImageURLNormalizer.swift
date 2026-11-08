import Foundation

/// Rewrites image URLs to the largest size the CDN will serve, and dedupes.
enum ImageURLNormalizer {
    static let targetWidth = 1600

    static func normalize(_ raw: String, relativeTo base: URL?) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !s.hasPrefix("data:") else { return nil }
        if s.hasPrefix("//") { s = "https:" + s }
        guard var url = URL(string: s, relativeTo: base)?.absoluteURL else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        if scheme == "http", var c = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            c.scheme = "https"
            url = c.url ?? url
        }
        let host = url.host()?.lowercased() ?? ""

        // eBay: .../s-l500.jpg → .../s-l1600.jpg
        if host.hasSuffix("ebayimg.com") {
            let rewritten = url.absoluteString.replacingOccurrences(of: #"s-l\d+\."#, with: "s-l1600.", options: .regularExpression)
            return URL(string: rewritten) ?? url
        }

        // Shopify CDN (cdn.shopify.com or a shop's own /cdn/shop/ path).
        if host == "cdn.shopify.com" || url.path().contains("/cdn/shop/") {
            guard var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
            c.path = c.path.replacingOccurrences(of: #"_(\d+x\d*|x\d+|\d+x)(_crop_[a-z]+)?(@\dx)?(?=\.[a-zA-Z]+$)"#, with: "", options: .regularExpression)
            var items = (c.queryItems ?? []).filter { !["width", "height", "crop"].contains($0.name) }
            items.append(URLQueryItem(name: "width", value: String(targetWidth)))
            c.queryItems = items
            return c.url ?? url
        }
        return url
    }

    /// Identity for dedupe: host + path, ignoring size parameters.
    static func key(for url: URL) -> String {
        (url.host()?.lowercased() ?? "") + url.path().lowercased()
    }

    static func unique(_ raws: [String], base: URL?, limit: Int = 16) -> [URL] {
        var seen = Set<String>()
        var out: [URL] = []
        for raw in raws {
            guard let url = normalize(raw, relativeTo: base) else { continue }
            let k = key(for: url)
            guard !seen.contains(k) else { continue }
            seen.insert(k)
            out.append(url)
            if out.count == limit { break }
        }
        return out
    }
}
