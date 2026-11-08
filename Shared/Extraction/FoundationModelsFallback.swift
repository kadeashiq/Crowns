import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Last resort for pages with no structured data: Apple's on-device model
/// reads the page text and fills in what the heuristics missed. It only ever
/// fills empty fields; anything found earlier wins.
enum FoundationModelsFallback {
    static func fill(_ draft: inout ListingDraft, title: String, text: String) async {
        #if canImport(FoundationModels)
        guard let guess = await guess(title: title, text: text) else { return }
        apply(guess, to: &draft)
        #endif
    }
}

#if canImport(FoundationModels)
@Generable
struct WatchListingGuess {
    @Guide(description: "The watch manufacturer, for example Rolex, Omega or Seiko. Empty if the page doesn't say.")
    var brand: String
    @Guide(description: "The model name without the brand or reference number, for example Submariner Date or Speedmaster Professional. Empty if unclear.")
    var model: String
    @Guide(description: "The manufacturer's reference number exactly as written, for example 126610LN or 210.30.42.20.03.001. Empty if none is given.")
    var reference: String
    @Guide(description: "The asking price as a plain number with no currency symbol or separators, for example 12950. Use 0 if no price is given.")
    var price: Double
    @Guide(description: "The ISO 4217 code for the price's currency, for example GBP, USD or EUR. Empty if there is no price.")
    var currency: String
    @Guide(description: "Up to eight short specifications stated on the page, such as case size, movement, case material, dial, year or condition.")
    var specs: [WatchSpecGuess]
}

@Generable
struct WatchSpecGuess {
    @Guide(description: "A short label, for example Case size")
    var label: String
    @Guide(description: "A short value, for example 41 mm")
    var value: String
}

extension FoundationModelsFallback {
    static func guess(title: String, text: String) async -> WatchListingGuess? {
        guard SystemLanguageModel.default.isAvailable else { return nil }
        let session = LanguageModelSession(instructions: """
            You read web pages that sell watches: shops, auctions and brand sites. \
            Identify the one watch being sold and extract its details. \
            Use only facts stated in the page. Leave a field empty rather than guess.
            """)
        let prompt = "Page title: \(title)\n\nPage text:\n\(text.prefix(6000))"
        do {
            return try await session.respond(to: prompt, generating: WatchListingGuess.self).content
        } catch {
            return nil
        }
    }

    static func apply(_ guess: WatchListingGuess, to d: inout ListingDraft) {
        var used = false
        let brand = guess.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        if d.brand.isEmpty, !brand.isEmpty {
            d.brand = WatchBrands.canonical(brand) ?? brand
            used = true
        }
        if d.reference.isEmpty, let ref = ReferenceDetector.clean(guess.reference), ref.contains(where: \.isNumber) {
            d.reference = ref
            used = true
        }
        let model = WatchBrands.strip(d.brand, from: guess.model).trimmingCharacters(in: .whitespacesAndNewlines)
        if d.model.isEmpty, !model.isEmpty, model.count <= 60 {
            d.model = model
            used = true
        }
        let code = PriceParser.normalizedCode(guess.currency)
        if d.price == nil, guess.price >= 1, guess.price < 100_000_000, code.count == 3 {
            d.price = Money(amount: Decimal(guess.price.rounded()), currency: code)
            used = true
        }
        if d.specs.isEmpty {
            let specs = guess.specs.prefix(8).compactMap { s -> Spec? in
                let label = s.label.trimmingCharacters(in: .whitespacesAndNewlines)
                let value = s.value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !label.isEmpty, !value.isEmpty, label.count <= 30, value.count <= 80 else { return nil }
                return Spec(label: label, value: value)
            }
            if !specs.isEmpty {
                d.specs = Array(specs)
                used = true
            }
        }
        if used { d.sources.insert(.foundationModels) }
    }
}
#endif
