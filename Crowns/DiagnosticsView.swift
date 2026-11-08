import SwiftUI

/// What the share extension extracted from recent shares. Developer tool for
/// phases 1–4; export an entry and it becomes a test fixture.
struct DiagnosticsView: View {
    @State private var entries: [DiagnosticsLog.StoredEntry] = []

    var body: some View {
        List(entries) { stored in
            NavigationLink {
                DiagnosticDetail(stored: stored)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(stored.entry.url.flatMap { URL(string: $0)?.host() } ?? "No URL")
                        .font(.subheadline.weight(.semibold))
                    Text(summary(stored.entry.draft))
                        .font(.caption)
                        .lineLimit(2)
                    Text("\(stored.entry.steps.joined(separator: " → ")) · \(stored.entry.photoCount) photos · \(stored.entry.saved ? "saved" : "cancelled")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Diagnostics")
        .onAppear { entries = DiagnosticsLog.entries() }
    }

    private func summary(_ d: ListingDraft) -> String {
        let price = d.price.map { $0.isGBP ? PriceFormatter.pounds(pence: $0.pence ?? 0) : PriceFormatter.original($0) } ?? "no price"
        return [d.brand, d.model, d.reference, price].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

private struct DiagnosticDetail: View {
    let stored: DiagnosticsLog.StoredEntry

    var body: some View {
        let d = stored.entry.draft
        List {
            Section {
                row("Brand", d.brand)
                row("Model", d.model)
                row("Reference", d.reference)
                row("Price", d.price.map { "\($0.amount) \($0.currency)" } ?? "")
                row("Site", d.siteName)
                row("Title", d.pageTitle)
                row("Sources", d.sources.map(\.rawValue).sorted().joined(separator: ", "))
                row("Steps", stored.entry.steps.joined(separator: " → "))
            }
            Section("Specs") {
                ForEach(d.specs) { spec in row(spec.label, spec.value) }
            }
            Section("Images") {
                ForEach(d.imageURLs, id: \.self) { url in
                    Text(url.absoluteString).font(.caption2).lineLimit(2)
                }
            }
        }
        .navigationTitle(URL(string: stored.entry.url ?? "")?.host() ?? "Entry")
        .toolbar {
            ShareLink(item: stored.file)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value.isEmpty ? "—" : value).textSelection(.enabled)
        }
    }
}
