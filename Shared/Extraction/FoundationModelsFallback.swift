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

    /// Fills specs the page reading missed. Free and on-device, on iPhones
    /// with Apple Intelligence; other devices simply skip this step.
    static func fillSpecs(_ draft: inout ListingDraft, text: String) async {
        #if canImport(FoundationModels)
        guard let guess = await specsGuess(text: text) else { return }
        let added = guess.fields.compactMap { label, value -> Spec? in
            let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !draft.specs.contains(where: { $0.label == label }), isGrounded(value, in: text) else { return nil }
            return Spec(label: label, value: value)
        }
        guard !added.isEmpty else { return }
        draft.specs = SpecNormalizer.ordered(draft.specs + added)
        draft.sources.insert(.foundationModels)
        #endif
    }

    /// True only if what the model said really is on the page, so it can't
    /// invent a number or a material.
    static func isGrounded(_ value: String, in text: String) -> Bool {
        guard !value.isEmpty, value.count <= 80 else { return false }
        let source = text.lowercased()
        let words = value.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "." })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
        let checked = words.filter { $0.contains(where: \.isNumber) || $0.count >= 4 }
        return !checked.isEmpty && checked.allSatisfy { source.contains($0) }
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
struct WatchSpecsGuess: Sendable {
    @Guide(description: "The case diameter, for example 41 mm. Empty if the text doesn't state it.")
    var caseSize: String
    @Guide(description: "The case thickness or height, for example 9.5 mm. Empty if the text doesn't state it.")
    var thickness: String
    @Guide(description: "The movement type or name, for example Automatic. Empty if the text doesn't state it.")
    var movement: String
    @Guide(description: "The case material, for example Stainless steel. Empty if the text doesn't state it.")
    var caseMaterial: String
    @Guide(description: "The water resistance, for example 100 m. Empty if the text doesn't state it.")
    var waterResistance: String

    var fields: [(String, String)] {
        [("Case size", caseSize), ("Thickness", thickness), ("Movement", movement), ("Case", caseMaterial), ("Water resistance", waterResistance)]
    }
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

    /// Gives up after a few seconds, so a slow model never holds up saving.
    static func specsGuess(text: String) async -> WatchSpecsGuess? {
        guard SystemLanguageModel.default.isAvailable else { return nil }
        return await withTaskGroup(of: WatchSpecsGuess?.self) { group in
            group.addTask {
                let session = LanguageModelSession(instructions: """
                    You read web pages that sell watches. Find the listed details of the one watch being sold. \
                    Copy values exactly as written. Leave a field empty rather than guess.
                    """)
                return try? await session.respond(to: "Page text:\n\(text.prefix(6000))", generating: WatchSpecsGuess.self).content
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(8))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
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
