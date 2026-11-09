import Foundation
import Testing

/// Pasted items arrive as encoded data, not ready-made URLs and strings.
struct PasteLinkTests {
    @Test func readsAPastedURL() async {
        let provider = NSItemProvider(object: NSURL(string: "https://example.com/watch")!)
        #expect(await ShareInputReader.firstURL(from: [provider])?.absoluteString == "https://example.com/watch")
    }

    @Test func readsALinkInPastedText() async {
        let provider = NSItemProvider(object: "Look at https://example.com/watch" as NSString)
        #expect(await ShareInputReader.firstURL(from: [provider])?.absoluteString == "https://example.com/watch")
    }

    @Test func ignoresTextWithoutALink() async {
        let provider = NSItemProvider(object: "Not a link" as NSString)
        #expect(await ShareInputReader.firstURL(from: [provider]) == nil)
    }
}

struct WatchCatalogTests {
    @Test func catalogBrandsUseCanonicalSpelling() {
        for brand in WatchCatalog.brandsWithModels {
            #expect((WatchBrands.canonical(brand) ?? brand) == brand)
        }
    }

    @Test func offersBrandsAsYouType() {
        #expect(WatchCatalog.brands(matching: "ome").first?.brand == "Omega")
        #expect(WatchCatalog.brands(matching: "seiko").isEmpty)
    }

    @Test func offersModelsForTheChosenBrand() {
        let matches = WatchCatalog.models(matching: "speed", brand: "omega")
        #expect(matches.first?.title == "Omega Speedmaster Professional")
        #expect(matches.allSatisfy { $0.brand == "Omega" })
        #expect(WatchCatalog.models(matching: "", brand: "Tudor").first?.model == "Black Bay")
    }

    @Test func searchesEveryBrandBeforeOneIsChosen() {
        #expect(WatchCatalog.models(matching: "submar", brand: "").first?.brand == "Rolex")
        #expect(WatchCatalog.models(matching: "s", brand: "").isEmpty)
    }
}

struct EditableSpecTests {
    @Test func showsParsedSpecsAlongsideTheStandardFields() {
        let specs = EditableSpec.merging([Spec(label: "Year", value: "2021"), Spec(label: "Case size", value: "41 mm")])
        #expect(specs.first?.label == "Case size")
        #expect(specs.first?.value == "41 mm")
        #expect(specs.contains { $0.label == "Year" && $0.value == "2021" })
        #expect(specs.contains { $0.label == "Thickness" && $0.value.isEmpty })
        #expect(specs.filter { $0.label == "Case size" }.count == 1)
    }

    @Test func savesOnlyWhatIsFilledIn() {
        var specs = EditableSpec.merging([Spec(label: "Case size", value: "41 mm")])
        specs.append(EditableSpec(label: "Lume", value: "Super-LumiNova", isCustom: true))
        specs.append(EditableSpec(label: "lume", value: "Duplicate", isCustom: true))
        specs.append(EditableSpec(label: "", value: "No label", isCustom: true))
        let saved = EditableSpec.saved(specs)
        #expect(saved.map(\.label) == ["Case size", "Lume"])
        #expect(saved.last?.value == "Super-LumiNova")
    }
}
