import Foundation

/// Recognises manufacturer reference numbers: 126610LN, 210.30.42.20.03.001,
/// SBGA211, M79030N-0001, 5711/1A-010, IW371605, 16610.
enum ReferenceDetector {
    private static let placeholders: Set<String> = [
        "does not apply", "n/a", "na", "unknown", "not applicable", "none", "unbranded", "-", "—", "see description", "other",
    ]

    /// A spec or JSON-LD value, rejected if it is a placeholder.
    static func clean(_ value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if placeholders.contains(raw.lowercased()) { return nil }
        let stripped = stripPrefix(raw)
        return stripped.count <= 40 ? stripped : nil
    }

    static func isReferenceLike(_ token: String) -> Bool {
        score(token) >= 2
    }

    /// The most reference-like token in a title or short text.
    static func best(in text: String) -> String? {
        var best: (token: String, score: Int)?
        let tokens = text.split(whereSeparator: { $0.isWhitespace || $0 == "|" || $0 == "(" || $0 == ")" || $0 == "," || $0 == ";" })
        var previous = ""
        for raw in tokens {
            let token = trim(String(raw))
            var s = score(token)
            if s > 0, ["ref", "ref.", "ref:", "reference", "reference:", "ref.:"].contains(previous.lowercased()) { s += 2 }
            if s >= 2, best == nil || s > best!.score {
                best = (stripPrefix(token), s)
            }
            previous = String(raw)
        }
        return best?.token
    }

    static func score(_ raw: String) -> Int {
        let t = stripPrefix(trim(raw))
        guard (4...24).contains(t.count) else { return 0 }
        let digits = t.filter(\.isNumber).count
        let letters = t.filter(\.isLetter).count
        guard digits >= 3 else { return 0 }
        if t.contains(where: { "£$€¥,".contains($0) }) { return 0 }
        if t.range(of: #"^\d+([.,]\d+)?\s?(mm|m|ft|atm|bar|k|kt|ct|g|h|hrs|hours|jewels|cm|in)$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return 0
        }
        if letters == 0 {
            if t.contains(".") {
                let parts = t.split(separator: ".")
                return parts.count >= 3 && parts.allSatisfy { $0.allSatisfy(\.isNumber) } ? 4 : 0
            }
            let plain = t.filter(\.isNumber)
            if plain.count != t.count {
                // 5711/1, 1675-1: digits with separators.
                return t.count >= 5 ? 2 : 0
            }
            if plain.count == 4, let year = Int(plain), (1900...2039).contains(year) { return 0 }
            if plain.count > 7 { return 0 }
            return plain.count >= 5 ? 2 : 1
        }
        // Mixed letters and digits. Mostly letters means a word ("Chronomat44").
        if letters > digits * 2 { return 0 }
        return 3
    }

    private static func trim(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:()[]{}|\"'“”‘’#*").union(.whitespaces))
    }

    private static func stripPrefix(_ s: String) -> String {
        var t = s
        for prefix in ["Reference:", "Reference", "Ref.:", "Ref.", "Ref:", "Ref", "#"] where t.lowercased().hasPrefix(prefix.lowercased()) {
            let rest = t.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            // Only strip when something reference-like follows ("Ref.126610" yes, "Refurbished" no).
            if rest.first?.isNumber == true || (prefix.hasSuffix(".") || prefix.hasSuffix(":")) && !rest.isEmpty {
                t = rest
            }
            break
        }
        return t
    }
}
