import Foundation

/// Reads prices written the way shops write them: "£12,950.00", "US $4,250",
/// "€ 2.300,00", "CHF 8'900.–", "3150.0".
enum PriceParser {
    /// Ordered so the more specific markers win ("US $" before "$").
    private static let markers: [(pattern: String, code: String)] = [
        ("US $", "USD"), ("US$", "USD"), ("USD", "USD"),
        ("AU $", "AUD"), ("AU$", "AUD"), ("A$", "AUD"), ("AUD", "AUD"),
        ("C $", "CAD"), ("CA$", "CAD"), ("C$", "CAD"), ("CAD", "CAD"),
        ("HK$", "HKD"), ("HKD", "HKD"),
        ("S$", "SGD"), ("SGD", "SGD"),
        ("NZ$", "NZD"), ("NZD", "NZD"),
        ("£", "GBP"), ("GBP", "GBP"),
        ("€", "EUR"), ("EUR", "EUR"),
        ("CHF", "CHF"), ("Fr.", "CHF"),
        ("¥", "JPY"), ("JPY", "JPY"), ("円", "JPY"),
        ("SEK", "SEK"), ("DKK", "DKK"), ("NOK", "NOK"),
        ("AED", "AED"),
        ("$", "USD"),
    ]

    /// Parses a price with its currency. `fallbackCurrency` applies when the
    /// text has a bare number (e.g. JSON-LD "price": "3150.0").
    static func parse(_ text: String, fallbackCurrency: String? = nil) -> Money? {
        guard let amount = decimal(in: text), amount > 0 else { return nil }
        guard let currency = currencyCode(in: text) ?? fallbackCurrency.map(normalizedCode) else { return nil }
        return Money(amount: amount, currency: currency)
    }

    static func currencyCode(in text: String) -> String? {
        let upper = text.uppercased()
        for marker in markers where upper.contains(marker.pattern.uppercased()) {
            return marker.code
        }
        return nil
    }

    static func normalizedCode(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if t.count == 3, t.allSatisfy(\.isLetter) { return t }
        return currencyCode(in: t) ?? t
    }

    /// The first number in the text, with thousands and decimal separators
    /// worked out from their positions rather than the locale.
    static func decimal(in text: String) -> Decimal? {
        // Digits with any of , . ' ’ or (narrow) spaces between them.
        let pattern = #"\d[\d,\.'’\u00A0\u202F ]*"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        var raw = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ",.'’ \u{00A0}\u{202F}"))
        raw = raw.replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")

        // A run like "4,250.00 3,312.40" (two prices) — keep the first.
        if let space = raw.firstIndex(of: " ") {
            let head = String(raw[..<space])
            let tail = raw[raw.index(after: space)...]
            // "12 950" is one number with a space separator; "4,250.00 3,312" is two.
            if head.contains(",") || head.contains(".") || tail.count != 3 {
                raw = head
            } else {
                raw = raw.replacingOccurrences(of: " ", with: "")
            }
        }

        let lastComma = raw.lastIndex(of: ",")
        let lastDot = raw.lastIndex(of: ".")
        var normalized: String
        switch (lastComma, lastDot) {
        case let (c?, d?):
            // Whichever comes last is the decimal separator.
            if c > d {
                normalized = raw.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                normalized = raw.replacingOccurrences(of: ",", with: "")
            }
        case let (c?, nil):
            let decimals = raw.distance(from: c, to: raw.endIndex) - 1
            let commas = raw.filter { $0 == "," }.count
            normalized = (decimals == 2 && commas == 1)
                ? raw.replacingOccurrences(of: ",", with: ".")
                : raw.replacingOccurrences(of: ",", with: "")
        case let (nil, d?):
            let decimals = raw.distance(from: d, to: raw.endIndex) - 1
            let dots = raw.filter { $0 == "." }.count
            normalized = (dots > 1 || decimals == 3)
                ? raw.replacingOccurrences(of: ".", with: "")
                : raw
        case (nil, nil):
            normalized = raw
        }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }
}
