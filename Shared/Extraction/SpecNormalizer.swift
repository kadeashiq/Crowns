import Foundation

/// Label/value pairs as found on the page, with lookup by label.
struct SpecTable {
    private(set) var pairs: [(label: String, value: String)] = []

    init(_ raw: [[String]]) {
        for pair in raw where pair.count >= 2 {
            append(pair[0], pair[1])
        }
    }

    mutating func append(_ label: String, _ value: String) {
        let l = label.trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespacesAndNewlines))
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !l.isEmpty, !v.isEmpty, !pairs.contains(where: { SpecTable.key($0.label) == SpecTable.key(l) }) else { return }
        pairs.append((l, v))
    }

    /// The value for the first matching label, compared case-insensitively.
    func value(_ labels: String...) -> String? {
        for label in labels {
            let k = SpecTable.key(label)
            if let hit = pairs.first(where: { SpecTable.key($0.label) == k }) { return hit.value }
        }
        return nil
    }

    static func key(_ s: String) -> String {
        s.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespacesAndNewlines))
    }
}

/// Maps the many ways shops label specs onto one short, ordered set.
enum SpecNormalizer {
    private static let canon: [(label: String, keys: [String])] = [
        ("Case size", ["case size", "case diameter", "diameter", "case width", "case size (mm)", "case dimensions", "size"]),
        ("Thickness", ["thickness", "case thickness", "case depth", "case height"]),
        ("Lug width", ["lug width", "lug size"]),
        ("Movement", ["movement", "movement type", "winding", "mechanism", "type of movement"]),
        ("Calibre", ["calibre", "caliber", "movement calibre", "movement caliber", "calibre number", "caliber number"]),
        ("Power reserve", ["power reserve"]),
        ("Case", ["case material", "material", "case"]),
        ("Dial", ["dial colour", "dial color", "dial"]),
        ("Bezel", ["bezel", "bezel material", "bezel type"]),
        ("Crystal", ["crystal", "glass", "crystal material"]),
        ("Bracelet", ["bracelet", "strap", "band", "band material", "bracelet material", "strap material", "bracelet/strap"]),
        ("Water resistance", ["water resistance", "water resistant", "water-resistance", "water resistance rating"]),
        ("Year", ["year", "year manufactured", "year of manufacture", "production year", "year of production"]),
        ("Condition", ["condition"]),
        ("Box", ["with original box/packaging", "original box", "with box", "box"]),
        ("Papers", ["with papers", "papers", "with original papers"]),
        ("Scope of delivery", ["scope of delivery", "included", "what's included", "box & papers", "box and papers"]),
    ]

    static func specs(from table: SpecTable, title: String) -> [Spec] {
        var out: [Spec] = []
        for (label, keys) in canon {
            var value: String?
            for key in keys {
                guard let v = table.value(key) else { continue }
                // "Size" alone is often S/M/L; only accept it with a measurement.
                if key == "size", !v.lowercased().contains("mm") { continue }
                value = v
                break
            }
            guard var v = value else { continue }
            if label == "Condition", let colon = v.firstIndex(of: ":"), v.distance(from: v.startIndex, to: colon) < 24 {
                v = String(v[..<colon])
            }
            if v.count > 80 { v = String(v.prefix(77)).trimmingCharacters(in: .whitespaces) + "…" }
            out.append(Spec(label: label, value: v))
        }
        if !out.contains(where: { $0.label == "Case size" }), let size = caseSize(in: title) {
            out.insert(Spec(label: "Case size", value: size), at: 0)
        }
        return out
    }

    /// "41mm" or "41 mm" in a title → "41 mm".
    static func caseSize(in text: String) -> String? {
        guard let r = text.range(of: #"\b([2-5]\d(\.\d)?)\s?mm\b"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let number = text[r].filter { $0.isNumber || $0 == "." }
        return "\(number) mm"
    }
}
