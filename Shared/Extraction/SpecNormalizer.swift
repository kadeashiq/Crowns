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

    /// The usual name for a label, such as "Case size" for "Case diameter".
    static func label(for raw: String) -> String {
        let key = SpecTable.key(raw)
        return canon.first { $0.keys.contains(key) }?.label ?? raw
    }

    /// Puts specs from any source into the usual order.
    static func ordered(_ specs: [Spec]) -> [Spec] {
        let rank = Dictionary(uniqueKeysWithValues: canon.enumerated().map { ($1.label, $0) })
        return specs.enumerated()
            .sorted { (rank[$0.element.label] ?? .max, $0.offset) < (rank[$1.element.label] ?? .max, $1.offset) }
            .map(\.element)
    }

    static func specs(from table: SpecTable, title: String, text: String = "") -> [Spec] {
        reading(from: table, title: title, text: text).specs
    }

    /// The specs, and the values found for any the page wasn't clear about:
    /// a measurement stated two different ways is left for the user to pick.
    static func reading(from table: SpecTable, title: String, text: String = "") -> (specs: [Spec], suggestions: [String: [String]]) {
        var out: [Spec] = []
        var unsure: [String: [String]] = [:]
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
            var values: [String] = []
            for found in captures(patterns, in: text) {
                let value = format(found)
                if !values.contains(where: { sameMeasure($0, value) }) { values.append(value) }
            }
            if values.count == 1 {
                out.append(Spec(label: label, value: values[0]))
            } else if values.count > 1 {
                unsure[label] = Array(values.prefix(3))
            }
        }
        if !out.contains(where: { $0.label == "Case size" }), unsure["Case size"] == nil, let size = caseSize(in: title) {
            out.append(Spec(label: "Case size", value: size))
        }
        return (ordered(out), unsure)
    }

    /// "100 meters" and "100m" say the same thing.
    private static func sameMeasure(_ a: String, _ b: String) -> Bool {
        func number(_ s: String) -> String { String(s.prefix { $0.isNumber || $0 == "." || $0 == " " }).filter { $0 != " " } }
        let (x, y) = (number(a), number(b))
        return x.isEmpty || y.isEmpty ? a.caseInsensitiveCompare(b) == .orderedSame : x == y
    }

    /// Between a label and its number: words that would mean the number
    /// belongs to something else on the watch.
    private static let labelGap = #"(?:(?!lug|length|thick|height|depth|crystal|strap|bracelet|clasp|\bto\b|[+/])[^.\n\d]){0,24}"#

    /// For specs written as sentences: "a case thickness of 9.5mm", "36mm case width".
    private static let sentencePatterns: [(String, [String], (String) -> String)] = [
        ("Case size", [
            #"(?<![\d.])(\d{2}(?:\.\d+)?)\s?mm\s+(?:(?:case\s+)?(?:width|diameter)|case\b(?!\s+(?:length|thick|height|depth|back)))"#,
            #"\b(?:case|diameter|(?<!lug )(?<!strap )(?<!band )(?<!bracelet )width)"# + labelGap + #"(\d{2}(?:\.\d+)?)\s?mm"#,
        ], { "\($0) mm" }),
        ("Thickness", [
            #"(?<![\d.])(\d{1,2}(?:\.\d+)?)\s?mm\s+(?:case\s+)?(?:thick|high\b|height|depth)"#,
            #"(?<!crystal )\b(?:thick(?:ness)?|height|depth)"# + labelGap + #"(\d{1,2}(?:\.\d+)?)\s?mm"#,
        ], { "\($0) mm" }),
        ("Water resistance", [#"water[- ]?resist\w*[^.\n\d]{0,24}(\d+\s?(?:m|metres|meters|atm|bar)\b)"#, #"(\d+\s?(?:m|metres|meters|atm|bar))\s+water[- ]?resist"#], { $0 }),
        ("Power reserve", [#"power reserve[^.\n\d]{0,24}(\d+)\s?h"#, #"(\d+)[- ]?hours?[^.\n]{0,20}power reserve"#], { "\($0) hours" }),
        // Pre-owned listings.
        ("Year", [#"\b(?:year|circa|dated)\s*:?\s*((?:19[3-9]|20[0-3])\d)\b"#], { $0 }),
        ("Condition", [#"\b(unworn|brand new|new old stock|mint|excellent|very good|good|fair)\s+condition\b"#], { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }),
        ("Box", [#"\b(box (?:and|&) papers|full set|with (?:the )?(?:original )?box)\b"#], { _ in "Yes" }),
        ("Papers", [#"\b(box (?:and|&) papers|full set|with (?:the )?(?:original )?papers)\b"#], { _ in "Yes" }),
    ]

    /// Every match of the patterns, in order.
    private static func captures(_ patterns: [String], in text: String) -> [String] {
        var out: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range(at: 1), in: text) { out.append(String(text[range])) }
            }
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
