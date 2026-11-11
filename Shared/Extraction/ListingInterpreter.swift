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
        let product = bestProduct(in: s.jsonld ?? [], page: s.pageURL)
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
        d.model = model(table: table, product: product, name: name, h1: s.h1, title: s.title, siteName: d.siteName, brand: d.brand, reference: d.reference)
        d.price = price(product: product, shopify: shopify, micro: micro, meta: meta, priceTexts: s.priceTexts ?? [], s: s)
        d.summary = String((first(product?["description"]?.string, shopify?["description"]?.string, meta["og:description"], meta["description"]) ?? "").prefix(600))
        d.specs = SpecNormalizer.specs(
            from: table,
            title: name,
            text: ([name] + (s.specLines ?? []) + [d.summary]).joined(separator: "\n"),
            pageText: s.text ?? "",
            calibres: s.calibres ?? []
        )
        d.imageURLs = images(product: product, shopify: shopify, s: s, reference: d.reference)

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

    /// Sites that change watch without loading a new page (Rolex, for one)
    /// keep the last watch's product data and add the new one after it, so a
    /// product that names another page on the same site isn't this watch.
    private static func bestProduct(in nodes: [JSONValue], page: URL?) -> JSONValue? {
        func score(_ n: JSONValue) -> Int {
            var s = 0
            if n["offers"] != nil || n["hasVariant"]?.list.first?["offers"] != nil { s += 3 }
            if n["image"] != nil { s += 1 }
            if n["brand"] != nil { s += 1 }
            if n["name"] != nil { s += 1 }
            return s
        }
        let products = nodes.filter(\.isObject).filter { node in
            guard let page else { return true }
            let named = ([node["url"], node["@id"]] + (node["offers"]?.list.map { $0["url"] } ?? []))
                .compactMap { $0?.string.flatMap(URL.init(string:)) }
            return named.contains { isSamePage($0, as: page) } || !named.contains { isOtherPage($0, than: page) }
        }
        return products.max { score($0) < score($1) }
    }

    /// The last part of a page's path, which names the watch: "m126610ln-0001",
    /// "4600e-000a-h177" (".html" dropped), "falcon" from "/collections/x/products/falcon".
    private static func pageName(_ url: URL) -> String {
        let name = url.path().split(separator: "/").last.map(String.init) ?? ""
        return (name.split(separator: ".").first.map(String.init) ?? name).lowercased()
    }

    private static func sameSite(_ a: URL, _ b: URL) -> Bool {
        func site(_ u: URL) -> String? { u.host()?.lowercased().replacingOccurrences(of: "www.", with: "") }
        return site(a) != nil && site(a) == site(b)
    }

    private static func isSamePage(_ url: URL, as page: URL) -> Bool {
        sameSite(url, page) && pageName(url) == pageName(page)
    }

    /// Another page on the same site. The home page doesn't count: some sites
    /// point every product at it.
    private static func isOtherPage(_ url: URL, than page: URL) -> Bool {
        sameSite(url, page) && !pageName(url).isEmpty && pageName(url) != pageName(page)
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
        if let other = candidates.first(where: { SpecTable.key($0) != site && !site.contains(SpecTable.key($0)) }) {
            return other
        }
        // Unless the shop is the brand: its web address spells the name
        // ("kiwametokyo.com" for "KIWAME TOKYO ASAKUSA").
        return host.flatMap { brandSpelled(by: $0, in: siteName) } ?? ""
    }

    /// The words at the start of a site name that its web address spells out.
    static func brandSpelled(by host: String, in siteName: String) -> String? {
        let label = host.lowercased().replacingOccurrences(of: "www.", with: "").split(separator: ".").first.map(String.init) ?? ""
        guard label.count >= 4 else { return nil }
        var spelled = ""
        var words: [Substring] = []
        for word in siteName.split(separator: " ") {
            spelled += word.lowercased().filter { $0.isLetter || $0.isNumber }
            words.append(word)
            if spelled == label { return readable(words.joined(separator: " ")) }
            if !label.hasPrefix(spelled) { return nil }
        }
        return nil
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
        // Nothing in the title: brands that sell direct often use the reference as the SKU.
        if let v = ReferenceDetector.clean(product?["sku"]?.string ?? micro["sku"]), ReferenceDetector.isReferenceLike(v) {
            return v
        }
        // Brand sites often print the reference near the top of the page but
        // not in the title. Only accept unmistakable shapes from body text.
        if let text, let v = ReferenceDetector.best(in: String(text.prefix(1200))), ReferenceDetector.score(v) >= 4 {
            return v
        }
        return ""
    }

    private static func model(table: SpecTable, product: JSONValue?, name: String, h1: String?, title: String?, siteName: String, brand: String, reference: String) -> String {
        let fields = [table.value("model", "model name"), product?["model"]?.string]
            .compactMap(ReferenceDetector.clean)
            .filter { !ReferenceDetector.isReferenceLike($0) }
        for field in fields {
            let derived = deriveModel(from: field, brand: brand, reference: reference)
            if !derived.isEmpty { return readable(derived) }
        }
        // Titles skip clean(): its length limit is for spec values, and listing titles run long.
        let titles = [name, h1, title.map { cleanTitle($0, siteName: siteName) }].compactMap { $0 }
        let derived = titles.map { deriveModel(from: $0, brand: brand, reference: reference) }.filter { !$0.isEmpty }
        guard let first = derived.first else { return "" }
        // A product's short name ("Moon") is often the end of a fuller one
        // elsewhere on the page ("Master Ultra Thin Moon").
        let fuller = derived.filter { (" " + $0.lowercased() + " ").contains(" " + first.lowercased() + " ") && $0.count > first.count }.max { $0.count < $1.count }
        return readable(fuller ?? first)
    }

    /// "SPIRIT PILOT" → "Spirit Pilot". Short capitals such as GMT or II stay as they are.
    static func readable(_ model: String) -> String {
        model.split(separator: " ").map { word in
            word.split(separator: "-", omittingEmptySubsequences: false).map { part in
                let letters = part.filter(\.isLetter)
                guard letters.count > 3, letters == letters.uppercased(), !part.contains(where: \.isNumber) else { return String(part) }
                return part.prefix(1) + part.dropFirst().lowercased()
            }.joined(separator: "-")
        }.joined(separator: " ")
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

    /// The product's own photos. A shop's product data is trusted when it
    /// lists several. Otherwise the page's gallery, and other large images
    /// only if they share the main photo's folder or name the reference.
    private static func images(product: JSONValue?, shopify: JSONValue?, s: PageSnapshot, reference: String) -> [URL] {
        func urls(from value: JSONValue?) -> [String] {
            (value?.list ?? []).compactMap { item in
                if item.isObject { return item["url"]?.string ?? item["contentUrl"]?.string }
                return item.string
            }
        }
        let listed = urls(from: product?["image"]) + urls(from: shopify?["images"])
        let fromData = ImageURLNormalizer.unique(listed, base: s.pageURL)
        if fromData.count >= 2 { return fromData }

        let all = s.images ?? []
        let isLarge: (PageSnapshot.Image) -> Bool = { ($0.w ?? 0) == 0 || ($0.w ?? 0) >= 300 }
        // A gallery thumbnail stands for the largest copy of the same picture on the page.
        let gallery = all.filter { $0.g == true }.compactMap { image -> String? in
            if isLarge(image) { return image.src }
            let key = pictureKey(image.src, base: s.pageURL)
            return all.filter { pictureKey($0.src, base: s.pageURL) == key && isLarge($0) }.max { ($0.w ?? 0) < ($1.w ?? 0) }?.src
        }
        let found = pictures(listed + gallery, socialImages: s.metaImages ?? [], base: s.pageURL)
        if found.count >= 2 {
            // A page can have more than one slider. When several pictures
            // share the first gallery photo's folder, those are the product's.
            let first = pictures(gallery, socialImages: [], base: s.pageURL).first ?? found[0]
            let same = found.filter { isSameProduct($0, as: first, reference: reference) }
            return same.count >= 2 ? same : found
        }

        let others = ImageURLNormalizer.unique(all.filter { $0.g != true && (($0.w ?? 0) == 0 || ($0.w ?? 0) >= 300) }.map(\.src), base: s.pageURL)
        guard let main = found.first ?? others.first else { return [] }
        let related = others.filter { isSameProduct($0, as: main, reference: reference) }
        // Narrowed only when that still leaves a choice of photos.
        let extra = found.count + related.count >= 2 ? related : others
        return ImageURLNormalizer.unique((found + extra).map(\.absoluteString), base: nil)
    }

    /// One URL per picture. A shop often serves the same picture at several
    /// sizes; a social-sharing copy gives way to the page's own.
    private static func pictures(_ raws: [String], socialImages: [String], base: URL?) -> [URL] {
        var out: [URL] = []
        var social: Set<Int> = []
        var index: [String: Int] = [:]
        for (raw, isSocial) in socialImages.map({ ($0, true) }) + raws.map({ ($0, false) }) {
            guard let url = ImageURLNormalizer.normalize(raw, relativeTo: base) else { continue }
            let key = pictureKey(url)
            if let at = index[key] {
                if social.contains(at), !isSocial {
                    out[at] = url
                    social.remove(at)
                }
                continue
            }
            index[key] = out.count
            if isSocial { social.insert(out.count) }
            out.append(url)
            if out.count == 16 { break }
        }
        return out
    }

    /// The folder and the name before the first dot: "…/Iw/IwVLA.jpeg.transform.vacthmb.jpeg"
    /// and "…/Iw/IwVLA.jpeg.transform.vacdetail.jpeg" are one picture.
    private static func pictureKey(_ url: URL) -> String {
        let path = url.path().lowercased()
        let folder = (path as NSString).deletingLastPathComponent
        let name = (path as NSString).lastPathComponent.split(separator: ".").first.map(String.init) ?? ""
        return (url.host()?.lowercased() ?? "") + folder + "/" + name
    }

    private static func pictureKey(_ raw: String, base: URL?) -> String {
        ImageURLNormalizer.normalize(raw, relativeTo: base).map(pictureKey) ?? raw
    }

    /// Photos of one product usually share a folder, or carry its reference.
    private static func isSameProduct(_ url: URL, as main: URL, reference: String) -> Bool {
        let path = url.path().lowercased()
        let folder = (path as NSString).deletingLastPathComponent
        let mainFolder = (main.path().lowercased() as NSString).deletingLastPathComponent
        if folder.split(separator: "/").count >= 2, folder == mainFolder { return true }
        let code = reference.lowercased()
        return code.count >= 5 && path.contains(code)
    }

    // MARK: - Helpers

    private static func sourceURL(for s: PageSnapshot) -> URL? {
        let page = s.pageURL
        // A canonical link left over from the last watch names another page.
        if let canonical = s.canonical.flatMap(URL.init(string:)), canonical.host() != nil,
           page.map({ canonical.host() == $0.host() && !isOtherPage(canonical, than: $0) }) ?? true {
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
            let next = i + 1 < tokens.count ? trimmedToken(tokens[i + 1]).lowercased() : ""
            let isNoise = token.isEmpty
                || separators.contains(lower)
                || noise.contains(lower)
                || (colours.contains(lower) && colourFollowers.contains(next))
                || lower.range(of: #"^\d+(\.\d+)?(mm|ct|k|kt)$"#, options: .regularExpression) != nil
                || (lower.allSatisfy { $0.isNumber || $0 == "." } && ["mm", "ct", "k", "kt"].contains(next))
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
