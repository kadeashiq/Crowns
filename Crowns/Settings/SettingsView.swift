import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var store
    @Environment(SyncMonitor.self) private var sync

    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]
    @Query private var watches: [Watch]

    @State private var showPaywall = false
    @State private var manageSubscription = false
    @State private var editingBox: BoxEditRequest?
    @State private var showDiagnostics = false
    @State private var restoreNote = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.isPro {
                        LabeledContent("Crowns Pro", value: "Active")
                        Button("Manage subscription") { manageSubscription = true }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            LabeledContent("Crowns Pro") {
                                Text("\(min(watches.count, ProStore.freeLimit)) of \(ProStore.freeLimit) free")
                            }
                        }
                        Button("Restore purchases") {
                            Task { restoreNote = await store.restore() ? "" : "Nothing to restore" }
                        }
                    }
                } footer: {
                    if !restoreNote.isEmpty { Text(restoreNote) }
                }

                Section("Boxes") {
                    ForEach(boxes) { box in
                        Button {
                            editingBox = BoxEditRequest(box: box)
                        } label: {
                            LabeledContent(box.name) {
                                Text("\(box.watches?.count ?? 0)")
                                    .monospacedDigit()
                            }
                        }
                    }
                    .onMove(perform: moveBoxes)
                    Button("New box") { editingBox = BoxEditRequest(box: nil) }
                }

                Section("iCloud") {
                    LabeledContent("Sync", value: sync.statusText)
                    if let last = sync.lastSync {
                        LabeledContent("Last synced") {
                            Text(last, format: .relative(presentation: .named))
                        }
                    }
                    if let error = sync.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    if showDiagnostics {
                        NavigationLink("Diagnostics") { DiagnosticsView() }
                    }
                    if let privacy = AppLinks.privacy {
                        Link("Privacy", destination: privacy)
                    }
                    Link("Terms of use", destination: AppLinks.terms)
                    LabeledContent("Version", value: version)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.desk)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                ZStack {
                    Theme.deskBackground
                    ScrollView {
                        PaywallView(store: store) { _ in showPaywall = false }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $editingBox) { request in
                BoxEditorSheet(box: request.box) { _ in editingBox = nil }
            }
            .manageSubscriptionsSheet(isPresented: $manageSubscription)
        }
        .preferredColorScheme(.dark)
        .task {
            await sync.checkAccount()
            showDiagnostics = await Self.isDevelopmentBuild()
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private func moveBoxes(from source: IndexSet, to destination: Int) {
        var ordered = boxes
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, box) in ordered.enumerated() { box.sortIndex = index }
        try? context.save()
    }

    /// Diagnostics show in debug and TestFlight builds, never on the App Store.
    private static func isDevelopmentBuild() async -> Bool {
        #if DEBUG
        return true
        #else
        let result = try? await AppTransaction.shared
        guard case .verified(let transaction)? = result else { return false }
        return transaction.environment != .production
        #endif
    }
}
