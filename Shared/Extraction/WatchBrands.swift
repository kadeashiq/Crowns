import Foundation

/// Known watch brands, used to recognise a brand in a title or domain and to
/// tidy its spelling ("OMEGA" → "Omega", "TAG HEUER" → "TAG Heuer").
enum WatchBrands {
    /// Canonical name, then other spellings seen in listings.
    private static let table: [(name: String, aliases: [String])] = [
        ("A. Lange & Söhne", ["A. Lange & Sohne", "A Lange & Sohne", "A. Lange und Söhne", "Lange & Söhne", "Lange & Sohne", "A. Lange"]),
        ("Audemars Piguet", []),
        ("Patek Philippe", ["Patek"]),
        ("Vacheron Constantin", []),
        ("Jaeger-LeCoultre", ["Jaeger LeCoultre", "Jaeger-Le Coultre", "JLC"]),
        ("Grand Seiko", []),
        ("King Seiko", []),
        ("TAG Heuer", ["Tag-Heuer"]),
        ("Baume & Mercier", ["Baume et Mercier"]),
        ("Ulysse Nardin", []),
        ("Girard-Perregaux", ["Girard Perregaux"]),
        ("Glashütte Original", ["Glashutte Original"]),
        ("Frederique Constant", ["Frédérique Constant"]),
        ("Christopher Ward", []),
        ("Bell & Ross", ["Bell and Ross"]),
        ("Richard Mille", []),
        ("F.P. Journe", ["FP Journe", "F. P. Journe"]),
        ("H. Moser & Cie", ["H. Moser", "Moser & Cie"]),
        ("Franck Muller", []),
        ("Carl F. Bucherer", ["Bucherer"]),
        ("Maurice Lacroix", []),
        ("Raymond Weil", []),
        ("Universal Genève", ["Universal Geneve"]),
        ("Jaquet Droz", []),
        ("Parmigiani Fleurier", ["Parmigiani"]),
        ("Laurent Ferrier", []),
        ("De Bethune", []),
        ("Arnold & Son", []),
        ("Armin Strom", []),
        ("Furlan Marri", []),
        ("Studio Underd0g", ["Studio Underdog"]),
        ("Tornek-Rayville", []),
        ("Mühle-Glashütte", ["Muhle Glashutte", "Mühle Glashütte"]),
        ("Nomos Glashütte", ["NOMOS Glashutte"]),
        ("Nomos", []),
        ("Rolex", []),
        ("Tudor", []),
        ("Omega", []),
        ("Cartier", []),
        ("IWC", ["IWC Schaffhausen"]),
        ("Panerai", ["Officine Panerai"]),
        ("Breitling", []),
        ("Zenith", []),
        ("Hublot", []),
        ("Blancpain", []),
        ("Breguet", []),
        ("Chopard", []),
        ("Bulgari", ["Bvlgari"]),
        ("Piaget", []),
        ("Montblanc", ["Mont Blanc"]),
        ("Longines", []),
        ("Tissot", []),
        ("Hamilton", []),
        ("Oris", []),
        ("Seiko", []),
        ("Credor", []),
        ("Citizen", []),
        ("Casio", []),
        ("G-Shock", ["G Shock"]),
        ("Orient", []),
        ("Junghans", []),
        ("Mido", []),
        ("Rado", []),
        ("Certina", []),
        ("Bremont", []),
        ("Farer", []),
        ("Baltic", []),
        ("Formex", []),
        ("Doxa", []),
        ("Squale", []),
        ("Halios", []),
        ("Lorier", []),
        ("Unimatic", []),
        ("Sinn", []),
        ("Damasko", []),
        ("Laco", []),
        ("Stowa", []),
        ("Fortis", []),
        ("Eterna", []),
        ("Alpina", []),
        ("Ball", ["Ball Watch"]),
        ("Bulova", []),
        ("Timex", []),
        ("Swatch", []),
        ("Heuer", []),
        ("MB&F", []),
        ("Czapek", []),
        ("Grönefeld", ["Gronefeld"]),
        ("Kurono", ["Kurono Tokyo"]),
        ("Minase", []),
        ("Anordain", []),
        ("Serica", []),
        ("Vaer", []),
        ("Zodiac", []),
        ("Glycine", []),
        ("Yema", []),
        ("Lip", []),
        ("Vostok", []),
        ("Raketa", []),
        ("Pagani Design", []),
        ("Steinhart", []),
        ("Apple", ["Apple Watch"]),
        ("Garmin", []),
    ]

    /// Every spelling, longest first, so "Grand Seiko" wins over "Seiko".
    private static let spellings: [(spelling: String, name: String)] = table
        .flatMap { entry in ([entry.name] + entry.aliases).map { (spelling: $0, name: entry.name) } }
        .sorted { $0.spelling.count > $1.spelling.count }

    /// Brands too common as ordinary words to trust inside a sentence or URL.
    private static let ambiguous: Set<String> = ["Ball", "Lip", "Apple", "Orient", "Citizen", "Zenith", "Hamilton", "Laco", "Vaer", "Baltic", "Farer"]

    static var names: [String] { table.map(\.name) }

    /// The canonical name if `raw` is a known brand, e.g. "OMEGA" → "Omega".
    static func canonical(_ raw: String) -> String? {
        let key = fold(raw)
        guard !key.isEmpty else { return nil }
        return namesBySpelling[key]
    }

    private static let namesBySpelling = Dictionary(spellings.map { (fold($0.spelling), $0.name) }, uniquingKeysWith: { first, _ in first })

    /// A known brand appearing as whole words in `text`, and where it is.
    static func find(in text: String) -> (name: String, range: Range<String.Index>)? {
        var best: (name: String, range: Range<String.Index>)?
        for (spelling, name) in spellings {
            guard let range = wordRange(of: spelling, in: text) else { continue }
            // Earliest mention wins; among equal starts, the longest spelling (sorted first).
            if best == nil || range.lowerBound < best!.range.lowerBound {
                best = (name, range)
            }
        }
        return best
    }

    /// A brand named by the site's domain, e.g. tudorwatch.com → Tudor.
    static func find(inHost host: String) -> String? {
        let squashed = fold(host).filter { $0.isLetter || $0.isNumber }
        for (spelling, name) in spellings where !ambiguous.contains(name) {
            let key = fold(spelling).filter { $0.isLetter || $0.isNumber }
            if key.count >= 4, squashed.contains(key) { return name }
        }
        return nil
    }

    /// Removes the brand (any spelling) from the start or middle of a title.
    static func strip(_ brand: String, from text: String) -> String {
        var result = text
        let candidates = spellings.filter { $0.name == brand }.map(\.spelling) + [brand]
        for spelling in candidates {
            if let range = wordRange(of: spelling, in: result) {
                result.removeSubrange(range)
                break
            }
        }
        return result
    }

    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "®", with: "")
            .replacingOccurrences(of: "™", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Case- and accent-insensitive match on word boundaries.
    static func wordRange(of needle: String, in haystack: String) -> Range<String.Index>? {
        var searchStart = haystack.startIndex
        while searchStart < haystack.endIndex,
              let range = haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], range: searchStart..<haystack.endIndex) {
            let beforeOK = range.lowerBound == haystack.startIndex || !isWordCharacter(haystack[haystack.index(before: range.lowerBound)])
            let afterOK = range.upperBound == haystack.endIndex || !isWordCharacter(haystack[range.upperBound])
            if beforeOK && afterOK { return range }
            searchStart = haystack.index(after: range.lowerBound)
        }
        return nil
    }

    private static func isWordCharacter(_ c: Character) -> Bool {
        c.isLetter || c.isNumber
    }
}
