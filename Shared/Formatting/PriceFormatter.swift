import Foundation

enum PriceFormatter {
    private static let gb = Locale(identifier: "en_GB")

    /// "£12,950", or "£12,950.50" when there are pence.
    static func pounds(pence: Int) -> String {
        let amount = Decimal(pence) / 100
        return amount.formatted(.currency(code: "GBP").locale(gb).precision(.fractionLength(pence % 100 == 0 ? 0 : 2)))
    }

    /// A foreign price as the listing showed it: "$1,650", "€2,300", "CHF 8,900".
    static func original(_ money: Money) -> String {
        let locale: Locale = ["USD", "JPY"].contains(money.currency) ? Locale(identifier: "en_US") : gb
        let whole = money.amount == money.amount.roundedToWhole()
        return money.amount.formatted(.currency(code: money.currency).locale(locale).precision(.fractionLength(whole ? 0 : 2)))
    }

    /// The text to show in an editable £ field: "12950" or "12950.50".
    static func editingText(pence: Int?) -> String {
        guard let pence else { return "" }
        return pence % 100 == 0 ? String(pence / 100) : String(format: "%d.%02d", pence / 100, pence % 100)
    }

    /// Parses what someone typed in a £ field.
    static func pence(fromEditing text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let money = PriceParser.parse(trimmed, fallbackCurrency: "GBP") else { return nil }
        return Money(amount: money.amount, currency: "GBP").pence
    }
}

extension Decimal {
    func roundedToWhole() -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, 0, .plain)
        return result
    }
}
