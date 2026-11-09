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
        ("Thickness", ["thickness", "case thickness", "case depth", "case height", "height", "depth", "thickness (mm)"]),
        ("Lug width", ["lug width", "lug size"]),
        ("Lug to lug", ["lug-to-lug", "lug to lug", "lug to lug length", "lug-to-lug length"]),
        ("Movement", ["movement", "movement type", "winding", "mechanism", "type of movement"]),
        ("Calibre", ["calibre", "caliber", "movement calibre", "movement caliber", "calibre number", "caliber number"]),
        ("Power reserve", ["power reserve"]),
        ("Jewels", ["no of jewels", "number of jewels", "jewels"]),
        ("Complication", ["complication type", "complication", "complications", "functions"]),
        ("Case", ["case material", "material", "case"]),
        ("Dial", ["dial colour", "dial color", "dial"]),
        ("Bezel", ["bezel", "bezel material", "bezel type"]),
        ("Crystal", ["crystal", "glass", "crystal material"]),
        ("Bracelet", ["bracelet", "strap", "band", "band material", "bracelet material", "strap material", "bracelet/strap"]),
        ("Weight", ["case weight", "weight"]),
        ("Water resistance", ["water resistance", "water resistant", "water-resistance", "water resistance rating"]),
        ("Year", ["year", "year manufactured", "year of manufacture", "production year", "year of production"]),
        ("Condition", ["condition"]),
        ("Box", ["with original box/packaging", "original box", "with box", "box"]),
        ("Papers", ["with papers", "papers", "with original papers"]),
        ("Scope of delivery", ["scope of delivery", "included", "what's included", "box & papers", "box and papers"]),
    ]

    /// The specs worth looking harder for when a page doesn't give them plainly.
    static let essentials = ["Case size", "Thickness", "Movement", "Case", "Water resistance"]

    /// The specs always offered for editing, whether or not a page gave them.
    static let formFields = ["Case size", "Thickness", "Lug width", "Lug to lug", "Movement", "Power reserve", "Case", "Dial", "Bracelet", "Water resistance"]

    /// Every spec the app knows by name, in the usual order.
    static var labels: [String] { canon.map(\.label) }

    /// Puts specs from any source into the usual order.
    static func ordered(_ specs: [Spec]) -> [Spec] {
        let rank = Dictionary(uniqueKeysWithValues: canon.enumerated().map { ($1.label, $0) })
        return specs.enumerated()
            .sorted { (rank[$0.element.label] ?? .max, $0.offset) < (rank[$1.element.label] ?? .max, $1.offset) }
            .map(\.element)
    }

    static func specs(from table: SpecTable, title: String, text: String = "") -> [Spec] {
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
        for (label, patterns, format) in sentencePatterns where !out.contains(where: { $0.label == label }) {
            if let found = firstCapture(patterns, in: text) { out.append(Spec(label: label, value: format(found))) }
        }
        if !out.contains(where: { $0.label == "Case size" }), let size = caseSize(in: title) {
            out.append(Spec(label: "Case size", value: size))
        }
        return ordered(out)
    }

    /// For specs written as sentences: "a case thickness of 9.5mm".
    private static let sentencePatterns: [(String, [String], (String) -> String)] = [
        ("Case size", [#"(?:case|diameter|width)[^.\n\d]{0,24}(\d{2}(?:\.\d+)?)\s?mm"#], { "\($0) mm" }),
        ("Thickness", [#"(?:thick(?:ness)?|height|depth)[^.\n\d]{0,24}(\d{1,2}(?:\.\d+)?)\s?mm"#, #"(\d{1,2}(?:\.\d+)?)\s?mm\s+(?:thick|high)"#], { "\($0) mm" }),
        ("Water resistance", [#"water[- ]?resist\w*[^.\n\d]{0,24}(\d+\s?(?:m|metres|meters|atm|bar)\b)"#, #"(\d+\s?(?:m|metres|meters|atm|bar))\s+water[- ]?resist"#], { $0 }),
        ("Power reserve", [#"power reserve[^.\n\d]{0,24}(\d+)\s?h"#, #"(\d+)[- ]?hours?[^.\n]{0,20}power reserve"#], { "\($0) hours" }),
    ]

    private static func firstCapture(_ patterns: [String], in text: String) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text) else { continue }
            return String(text[range])
        }
        return nil
    }

    /// "41mm" or "41 mm" in a title → "41 mm".
    static func caseSize(in text: String) -> String? {
        guard let r = text.range(of: #"\b([2-5]\d(\.\d)?)\s?mm\b"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let number = text[r].filter { $0.isNumber || $0 == "." }
        return "\(number) mm"
    }
}
