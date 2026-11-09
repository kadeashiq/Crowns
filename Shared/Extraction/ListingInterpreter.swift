import Foundation

/// Turns a raw PageSnapshot into a ListingDraft.
///
/// Trust order, highest first: the page's own spec table (eBay item specifics
/// are filled in by the seller field by field), JSON-LD Product, Shopify's
/// product JSON, Open Graph / microdata, then heuristics over the title.
enum ListingInterpreter {
    static func interpret(_ s: PageSnapshot) -> ListingDraft {
        var d = ListingDraft()
        let meta = s.meta ?? [:]
        let product = bestProduct(in: s.jsonld ?? [])
        let shopify: JSONValue? = (s.shopify?.isObject == true) ? s.shopify : nil
        let micro = s.microdata ?? [:]

        var table = SpecTable(s.specs ?? [])
        for prop in product?["additionalProperty"]?.list ?? [] {
            if let n = prop["name"]?.string, let v = prop["value"]?.string { table.append(n, v) }
        }

        d.sourceURL = sourceURL(for: s)
        d.siteName = siteName(meta: meta, url: d.sourceURL ?? s.pageURL)

        let rawName = first(product?["name"]?.string, shopify?["title"]?.string, meta["og:title"], meta["twitter:title"], s.h1, s.title) ?? ""
        let name = cleanTitle(rawName, siteName: d.siteName)
        d.pageTitle = name
        let allTitles = [name, s.title, meta["og:title"], s.h1].compactMap { $0 }.joined(separator: " · ")

        d.brand = brand(table: table, product: product, shopify: shopify, micro: micro, meta: meta, name: name, allTitles: allTitles, siteName: d.siteName, host: d.sourceURL?.host())
        d.reference = reference(table: table, product: product, micro: micro, name: name, allTitles: allTitles, text: s.text)
        d.model = model(table: table, product: product, name: name, h1: s.h1, brand: d.brand, reference: d.reference)
        d.price = price(product: product, shopify: shopify, micro: micro, meta: meta, priceTexts: s.priceTexts ?? [], s: s)
        d.summary = String((first(product?["description"]?.string, shopify?["description"]?.string, meta["og:description"], meta["description"]) ?? "").prefix(600))
        d.specs = SpecNormalizer.specs(from: table, title: name, text: ((s.specLines ?? []) + [d.summary]).joined(separator: "\n"))
        d.imageURLs = images(product: product, shopify: shopify, s: s)

        if product != nil { d.sources.insert(.jsonLD) }
        if shopify != nil { d.sources.insert(.shopify) }
        if meta["og:title"] != nil || !(s.metaImages ?? []).isEmpty { d.sources.insert(.openGraph) }
        if !micro.isEmpty { d.sources.insert(.microdata) }
        if !table.pairs.isEmpty { d.sources.insert(.pageSpecs) }
        d.sources.insert(.heuristics)
        return d
    }

    /// Re-derives brand, reference and model from a bare title, for fallbacks
    /// (LinkPresentation) that give us nothing else.
    static func applyTitle(_ title: String, to d: inout ListingDraft) {
        let name = cleanTitle(title, siteName: d.siteName)
        if d.pageTitle.isEmpty { d.pageTitle = name }
        if d.brand.isEmpty {
            d.brand = WatchBrands.find(in: name)?.name ?? d.sourceURL?.host().flatMap(WatchBrands.find(inHost:)) ?? ""
        }
        if d.reference.isEmpty { d.reference = ReferenceDetector.best(in: name) ?? "" }
        if d.model.isEmpty { d.model = deriveModel(from: name, brand: d.brand, reference: d.reference) }
        if d.specs.isEmpty, let size = SpecNormalizer.caseSize(in: name) {
            d.specs = [Spec(label: "Case size", value: size)]
        }
    }

    // MARK: - Product node

    private static func bestProduct(in nodes: [JSONValue]) -> JSONValue? {
        func score(_ n: JSONValue) -> Int {
            var s = 0
            if n["offers"] != nil || n["hasVariant"]?.list.first?["offers"] != nil { s += 3 }
            if n["image"] != nil { s += 1 }
            if n["brand"] != nil { s += 1 }
            if n["name"] != nil { s += 1 }
            return s
        }
        return nodes.filter(\.isObject).max { score($0) < score($1) }
    }

    // MARK: - Fields

    private static func brand(table: SpecTable, product: JSONValue?, shopify: JSONValue?, micro: [String: String], meta: [String: String], name: String, allTitles: String, siteName: String, host: String?) -> String {
        let candidates = [
            table.value("brand", "manufacturer", "make"),
            product?["brand"]?.string,
            product?["manufacturer"]?.string,
            shopify?["vendor"]?.string,
            micro["brand"],
            meta["product:brand"],
            meta["og:brand"],
        ].compactMap { $0 }.filter { ReferenceDetector.clean($0) != nil }

        if let known = candidates.lazy.compactMap(WatchBrands.canonical).first { return known }
        if let found = WatchBrands.find(in: name) { return found.name }
        if let found = WatchBrands.find(in: allTitles) { return found.name }
        if let site = WatchBrands.canonical(siteName) ?? WatchBrands.find(in: siteName)?.name { return site }
        if let host, let fromHost = WatchBrands.find(inHost: host) { return fromHost }

        // An unknown brand, e.g. a microbrand. Shops often put their own name
        // in "brand", so skip anything that is just the site name.
        let site = SpecTable.key(siteName)
        return candidates.first { SpecTable.key($0) != site && !site.contains(SpecTable.key($0)) } ?? ""
    }

    private static func reference(table: SpecTable, product: JSONValue?, micro: [String: String], name: String, allTitles: String, text: String?) -> String {
        if let v = ReferenceDetector.clean(table.value("reference number", "reference", "reference no", "reference no.", "ref", "ref.", "model number", "mpn", "manufacturer part number")),
           v.contains(where: \.isNumber) {
            return v
        }
        if let v = ReferenceDetector.clean(product?["mpn"]?.string ?? micro["mpn"]), ReferenceDetector.score(v) >= 1 {
            return v
        }
        if let v = ReferenceDetector.clean(product?["model"]?.string ?? micro["model"]), ReferenceDetector.isReferenceLike(v) {
            return v
        }
        if let v = ReferenceDetector.best(in: name) ?? ReferenceDetector.best(in: allTitles) {
            return v
        }
        // Brand sites often print the reference near the top of the page but
        // not in the title. Only accept unmistakable shapes from body text.
        if let text, let v = ReferenceDetector.best(in: String(text.prefix(1200))), ReferenceDetector.score(v) >= 4 {
            return v
        }
        return ""
    }

    private static func model(table: SpecTable, product: JSONValue?, name: String, h1: String?, brand: String, reference: String) -> String {
        let fields = [table.value("model", "model name"), product?["model"]?.string]
            .compactMap(ReferenceDetector.clean)
            .filter { !ReferenceDetector.isReferenceLike($0) }
        // Titles skip clean(): its length limit is for spec values, and listing titles run long.
        for candidate in fields + [name, h1].compactMap({ $0 }) {
            let derived = deriveModel(from: candidate, brand: brand, reference: reference)
            if !derived.isEmpty { return derived }
        }
        return ""
    }

    private static func price(product: JSONValue?, shopify: JSONValue?, micro: [String: String], meta: [String: String], priceTexts: [String], s: PageSnapshot) -> Money? {
        let fallback = defaultCurrency(for: s)
        let metaCurrency = meta["product:price:currency"] ?? meta["og:price:currency"]

        // JSON-LD offers: Offer, [Offer], AggregateOffer, or on a variant.
        if let product {
            var offers = product["offers"]?.list ?? []
            if offers.isEmpty { offers = product["hasVariant"]?.list.first?["offers"]?.list ?? [] }
            for offer in offers {
                let spec = offer["priceSpecification"]?.list.first
                let amount = offer["price"]?.string ?? offer["lowPrice"]?.string ?? spec?["price"]?.string
                let currency = offer["priceCurrency"]?.string ?? spec?["priceCurrency"]?.string ?? metaCurrency ?? fallback
                if let amount, let money = PriceParser.parse(amount, fallbackCurrency: currency), sane(money) { return money }
            }
        }

        // Shopify product JSON: integer minor units.
        if let shopify {
            let currency = metaCurrency ?? priceTexts.lazy.compactMap(PriceParser.currencyCode(in:)).first ?? fallback
            if case .number(let cents)? = shopify["price"], cents > 0, let currency {
                let money = Money(amount: Decimal(cents) / 100, currency: PriceParser.normalizedCode(currency))
                if sane(money) { return money }
            }
        }

        if let amount = meta["product:price:amount"] ?? meta["og:price:amount"],
           let money = PriceParser.parse(amount, fallbackCurrency: metaCurrency ?? fallback), sane(money) {
            return money
        }
        if let amount = micro["price"], let money = PriceParser.parse(amount, fallbackCurrency: micro["priceCurrency"] ?? fallback), sane(money) {
            return money
        }
        for text in priceTexts {
            if let money = PriceParser.parse(text, fallbackCurrency: fallback), sane(money) { return money }
        }
        return nil
    }

    private static func sane(_ m: Money) -> Bool {
        m.amount >= 1 && m.amount < 100_000_000 && m.currency.count == 3
    }

    private static func images(product: JSONValue?, shopify: JSONValue?, s: PageSnapshot) -> [URL] {
        var raws: [String] = []
        func urls(from value: JSONValue?) -> [String] {
            (value?.list ?? []).compactMap { item in
                if item.isObject { return item["url"]?.string ?? item["contentUrl"]?.string }
                return item.string
            }
        }
        raws += urls(from: product?["image"])
        raws += urls(from: shopify?["images"])
        raws += s.metaImages ?? []
        raws += (s.images ?? []).filter { ($0.w ?? 0) == 0 || ($0.w ?? 0) >= 300 }.map(\.src)
        return ImageURLNormalizer.unique(raws, base: s.pageURL)
    }

    // MARK: - Helpers

    private static func sourceURL(for s: PageSnapshot) -> URL? {
        let page = s.pageURL
        if let canonical = s.canonical.flatMap(URL.init(string:)), canonical.host() != nil,
           canonical.host() == page?.host() || page == nil {
            return canonical
        }
        guard let page, var c = URLComponents(url: page, resolvingAgainstBaseURL: false) else { return page }
        c.queryItems = c.queryItems?.filter { !$0.name.hasPrefix("utm_") && !["fbclid", "gclid", "mkevt", "mkcid", "campid"].contains($0.name) }
        if c.queryItems?.isEmpty == true { c.queryItems = nil }
        return c.url ?? page
    }

    private static func siteName(meta: [String: String], url: URL?) -> String {
        if let name = meta["og:site_name"]?.trimmingCharacters(in: .whitespaces), !name.isEmpty { return name }
        guard var host = url?.host() else { return "" }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }

    /// "Tudor Black Bay 58 – Northern Time Co." → "Tudor Black Bay 58".
    static func cleanTitle(_ title: String, siteName: String) -> String {
        var parts = title.components(separatedBy: " | ")
            .flatMap { $0.components(separatedBy: " – ") }
            .flatMap { $0.components(separatedBy: " — ") }
            .flatMap { $0.components(separatedBy: " - ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let site = SpecTable.key(siteName)
        func isSiteLike(_ part: String) -> Bool {
            let k = SpecTable.key(part.replacingOccurrences(of: "®", with: ""))
            if k.contains("ebay") { return true }
            if !site.isEmpty && (k == site || k.contains(site) || site.contains(k)) { return true }
            let words = ["official", "online", "store", "shop", "boutique", "uk", "®"]
            return part.count < 30 && words.contains { k.contains($0) } && !k.contains(where: \.isNumber)
        }
        while parts.count > 1, let last = parts.last, isSiteLike(last) {
            parts.removeLast()
        }
        return parts.joined(separator: " - ")
    }

    private static let noise: Set<String> = [
        "watch", "watches", "wristwatch", "men's", "mens", "men", "gents", "gent's", "women's", "womens", "ladies", "lady", "unisex",
        "automatic", "auto", "quartz", "mechanical", "manual", "hand-wound", "handwound", "self-winding", "chronometer", "co-axial", "coaxial",
        "steel", "stainless", "oystersteel", "gold", "titanium", "ceramic", "platinum", "bronze", "carbon",
        "dial", "bracelet", "strap", "leather", "rubber", "nato", "hesalite", "sapphire",
        "box", "boxed", "papers", "full", "fullset", "set", "mint", "unworn", "new", "brand-new", "pre-owned", "preowned", "used",
        "vintage", "rare", "with", "w/", "and", "&", "+", "uk", "warranty", "serviced", "b&p", "card", "ref", "ref.", "reference",
    ]
    private static let colours: Set<String> = [
        "black", "blue", "green", "white", "silver", "grey", "gray", "red", "champagne", "brown", "pink", "purple", "yellow", "rose", "orange", "salmon", "cream", "ivory", "two-tone",
    ]
    private static let colourFollowers: Set<String> = ["dial", "bezel", "strap", "gold", "bracelet", "leather", "rubber", "face"]
    private static let separators: Set<String> = ["-", "–", "—", "|", "/", "·", "•", ":"]

    /// The model name from a listing title: drop the brand and reference,
    /// skip leading filler, stop at the first spec-like word, keep ≤ 4 words.
    static func deriveModel(from text: String, brand: String, reference: String) -> String {
        var t = text
        if !brand.isEmpty { t = WatchBrands.strip(brand, from: t) }
        if !reference.isEmpty { t = t.replacingOccurrences(of: reference, with: " ", options: .caseInsensitive) }
        let tokens = t.split(whereSeparator: \.isWhitespace).map(String.init)
        var words: [String] = []
        for (i, raw) in tokens.enumerated() {
            let token = trimmedToken(raw)
            let lower = token.lowercased()
                .replacingOccurrences(of: "\u{2011}", with: "-")
                .replacingOccurrences(of: "\u{2010}", with: "-")
            let next = i + 1 < tokens.count ? tokens[i + 1].lowercased() : ""
            let isNoise = token.isEmpty
                || separators.contains(lower)
                || noise.contains(lower)
                || (colours.contains(lower) && colourFollowers.contains(next))
                || lower.range(of: #"^\d+(\.\d+)?(mm|ct|k|kt)$"#, options: .regularExpression) != nil
                || lower.range(of: #"^(19|20)\d{2}$"#, options: .regularExpression) != nil
                || lower.contains(where: { "£$€".contains($0) })
                || ReferenceDetector.isReferenceLike(token)
            if isNoise {
                if words.isEmpty { continue } else { break }
            }
            words.append(token)
            if words.count == 4 { break }
        }
        return words.joined(separator: " ")
    }

    /// Drops punctuation around a title word, keeping brackets that belong
    /// to it: "(Pepsi)," → "Pepsi", but "KUBO(窪)" stays whole.
    private static func trimmedToken(_ raw: String) -> String {
        var token = raw.trimmingCharacters(in: CharacterSet(charactersIn: ",;:|\"“”"))
        for (open, close) in [("(", ")"), ("[", "]")] {
            if token.hasPrefix(open), token.hasSuffix(close) {
                token = String(token.dropFirst().dropLast())
            }
            if token.hasPrefix(open), !token.contains(close) { token.removeFirst() }
            if token.hasSuffix(close), !token.contains(open) { token.removeLast() }
        }
        return token
    }

    private static func defaultCurrency(for s: PageSnapshot) -> String? {
        let host = s.pageURL?.host()?.lowercased() ?? ""
        let lang = (s.lang ?? "").lowercased()
        if host.hasSuffix(".uk") || lang == "en-gb" { return "GBP" }
        if host.hasSuffix(".ch") { return "CHF" }
        if host.hasSuffix(".jp") { return "JPY" }
        if host.hasSuffix(".com.au") { return "AUD" }
        if host.hasSuffix(".ca") { return "CAD" }
        if [".de", ".fr", ".it", ".es", ".nl", ".at", ".be", ".ie"].contains(where: { host.hasSuffix($0) }) { return "EUR" }
        if host.hasSuffix(".com") && lang == "en-us" { return "USD" }
        return nil
    }

    private static func first(_ values: String?...) -> String? {
        values.lazy.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
    }
}
