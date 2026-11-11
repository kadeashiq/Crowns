import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Last resort for pages with no structured data: Apple's on-device model
/// reads the page text for what the heuristics missed. Its answers fill only
/// empty fields, and only when they appear on the page word for word and
/// look like what the field holds. Anything found earlier wins.
enum FoundationModelsFallback {
    /// Loads the model ahead of the first question.
    static func prewarm() {
        #if canImport(FoundationModels)
        guard SystemLanguageModel.default.isAvailable else { return }
        LanguageModelSession(instructions: listingInstructions).prewarm()
        #endif
    }

    static func fill(_ draft: inout ListingDraft, title: String, text: String) async {
        #if canImport(FoundationModels)
        guard let guess = await guess(title: title, text: text) else { return }
        apply(guess, to: &draft, page: title + "\n" + text)
        #endif
    }

    /// Fills specs the page reading missed. Free and on-device, on iPhones
    /// with Apple Intelligence; other devices simply skip this step.
    static func fillSpecs(_ draft: inout ListingDraft, text: String) async {
        #if canImport(FoundationModels)
        guard let guess = await specsGuess(text: text) else { return }
        var used = false
        for (label, value) in guess.fields {
            guard !draft.specs.contains(where: { $0.label == label }), let value = usable(value, for: label, in: text) else { continue }
            draft.specs = SpecNormalizer.ordered(draft.specs + [Spec(label: label, value: value)])
            used = true
        }
        if used { draft.sources.insert(.foundationModels) }
        #endif
    }

    /// A spec the model read, if the page says it and it's the right kind of
    /// value, cut to the measurement where there is one ("100 meters" from
    /// "100 meters of water resistance").
    static func usable(_ raw: String, for label: String, in text: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isGrounded(value, in: text), SpecNormalizer.fits(value, label: label) else { return nil }
        return SpecNormalizer.measurement(in: value, for: label) ?? value
    }

    /// True only if what the model said really is on the page, so it can't
    /// invent a number or a material.
    static func isGrounded(_ value: String, in text: String) -> Bool {
        guard !value.isEmpty, value.count <= 80 else { return false }
        let source = text.lowercased()
        let words = value.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "." })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
        let checked = words.filter { $0.contains(where: \.isNumber) || $0.count >= 4 }
        // Short names such as IWC have no long word to check, so the whole name must appear.
        if checked.isEmpty { return words.count == 1 && source.contains(value.lowercased()) }
        return checked.allSatisfy { source.contains($0) }
    }

    /// True if the page states this amount, written with or without separators.
    static func statesAmount(_ amount: Double, in text: String) -> Bool {
        let whole = String(Int(amount.rounded()))
        let joined = text.replacingOccurrences(of: #"(?<=\d)[,.'’   ](?=\d{3}\b)"#, with: "", options: .regularExpression)
        return joined.range(of: #"(?<![\d])"# + whole + #"(?![\d])"#, options: .regularExpression) != nil
    }
}

#if canImport(FoundationModels)
@Generable
struct WatchListingGuess: Sendable {
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
struct WatchSpecGuess: Sendable {
    @Guide(description: "A short label, for example Case size")
    var label: String
    @Guide(description: "A short value, for example 41 mm")
    var value: String
}

extension FoundationModelsFallback {
    fileprivate static let listingInstructions = """
        You read web pages that sell watches: shops, auctions and brand sites. \
        Identify the one watch being sold and extract its details. \
        Use only facts stated in the page. Leave a field empty rather than guess.
        """

    static func guess(title: String, text: String) async -> WatchListingGuess? {
        guard SystemLanguageModel.default.isAvailable else { return nil }
        let prompt = "Page title: \(title)\n\nPage text:\n\(text.prefix(6000))"
        return await answer(within: 15) {
            let session = LanguageModelSession(instructions: listingInstructions)
            return try? await session.respond(to: prompt, generating: WatchListingGuess.self).content
        }
    }

    static func specsGuess(text: String) async -> WatchSpecsGuess? {
        guard SystemLanguageModel.default.isAvailable else { return nil }
        let prompt = "Page text:\n\(text.prefix(6000))"
        return await answer(within: 8) {
            let session = LanguageModelSession(instructions: """
                You read web pages that sell watches. Find the listed details of the one watch being sold. \
                Copy values exactly as written. Leave a field empty rather than guess.
                """)
            return try? await session.respond(to: prompt, generating: WatchSpecsGuess.self).content
        }
    }

    /// Gives up after a few seconds, so a slow model doesn't run on for long.
    private static func answer<Guess: Sendable>(within seconds: Int, _ ask: @escaping @Sendable () async -> Guess?) async -> Guess? {
        await withTaskGroup(of: Guess?.self) { group in
            group.addTask(operation: ask)
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    static func apply(_ guess: WatchListingGuess, to d: inout ListingDraft, page: String) {
        var used = false
        // Only a brand the app knows: a model name read as the brand looks just as sure.
        let brand = guess.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        if d.brand.isEmpty, let known = WatchBrands.canonical(brand), isGrounded(brand, in: page) {
            d.brand = known
            used = true
        }
        if d.reference.isEmpty, let ref = ReferenceDetector.clean(guess.reference), ReferenceDetector.isReferenceLike(ref), isGrounded(ref, in: page) {
            d.reference = ref
            used = true
        }
        let model = WatchBrands.strip(d.brand.isEmpty ? brand : d.brand, from: guess.model).trimmingCharacters(in: .whitespacesAndNewlines)
        if d.model.isEmpty, !model.isEmpty, model.count <= 60, isGrounded(model, in: page) {
            d.model = model
            used = true
        }
        let code = PriceParser.normalizedCode(guess.currency)
        if d.price == nil, guess.price >= 1, guess.price < 100_000_000, code.count == 3, statesAmount(guess.price, in: page) {
            d.price = Money(amount: Decimal(guess.price.rounded()), currency: code)
            used = true
        }
        if d.specs.isEmpty {
            for s in guess.specs.prefix(8) {
                let label = SpecNormalizer.label(for: s.label.trimmingCharacters(in: .whitespacesAndNewlines))
                guard SpecNormalizer.labels.contains(label), !d.specs.contains(where: { $0.label == label }),
                      let value = usable(s.value, for: label, in: page) else { continue }
                d.specs.append(Spec(label: label, value: value))
                used = true
            }
            d.specs = SpecNormalizer.ordered(d.specs)
        }
        if used { d.sources.insert(.foundationModels) }
    }
}
#endif
