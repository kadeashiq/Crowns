import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncMonitor.self) private var sync

    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]

    @State private var editingBox: BoxEditRequest?
    @State private var showDeveloperTools = false
    @State private var showBoxOrder = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SheetHeader(title: "Settings")
                ScrollView {
                    VStack(spacing: Space.lg) {
                        boxesSection
                        iCloudSection
                        aboutSection
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.xs)
                    .padding(.bottom, Space.xl)
                }
                .scrollIndicators(.hidden)
            }
            .background(Theme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showBoxOrder) {
                BoxOrderSheet()
                    .presentationDetents([.medium, .large])
                    .crownsSheet()
            }
            .sheet(item: $editingBox) { request in
                BoxEditorSheet(box: request.box) { _ in editingBox = nil }
                    .crownsSheet()
            }
        }
        .task {
            await sync.checkAccount()
            showDeveloperTools = await Self.isDevelopmentBuild()
        }
    }

    // MARK: - Sections

    private var boxesSection: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                SectionLabel(text: "Boxes")
                Spacer()
                if boxes.count > 1 {
                    Button("Reorder") { showBoxOrder = true }
                    .font(Typeface.label)
                    .foregroundStyle(Theme.ink)
                    .buttonStyle(PressableStyle())
                }
            }
            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(boxes.enumerated()), id: \.element.id) { index, box in
                        if index > 0 { RowDivider() }
                        boxRow(box)
                    }
                    RowDivider()
                    Button { editingBox = BoxEditRequest(box: nil) } label: {
                        ValueRow(title: "New box") {
                            Image(systemName: "plus")
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private func boxRow(_ box: Box) -> some View {
        Button { editingBox = BoxEditRequest(box: box) } label: {
            ValueRow(title: box.name, showsChevron: true) {
                Text("\(box.watches?.count ?? 0)").monospacedDigit()
            }
        }
        .buttonStyle(PressableStyle())
    }

    private var iCloudSection: some View {
        FormSection(title: "iCloud", footer: sync.lastError ?? "", padding: 0) {
            VStack(spacing: 0) {
                ValueRow(title: "Sync", value: sync.statusText)
                if let last = sync.lastSync {
                    RowDivider()
                    ValueRow(title: "Last synced") {
                        Text(last, format: .relative(presentation: .named))
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        FormSection(padding: 0) {
            VStack(spacing: 0) {
                if showDeveloperTools {
                    NavigationLink { DesignSystemView() } label: {
                        ValueRow(title: "Design system", showsChevron: true)
                    }
                    .buttonStyle(PressableStyle())
                    RowDivider()
                    NavigationLink { DiagnosticsView() } label: {
                        ValueRow(title: "Diagnostics", showsChevron: true)
                    }
                    .buttonStyle(PressableStyle())
                    RowDivider()
                }
                if let privacy = AppLinks.privacy {
                    Link(destination: privacy) {
                        ValueRow(title: "Privacy", showsChevron: true)
                    }
                    .buttonStyle(PressableStyle())
                    RowDivider()
                }
                Link(destination: AppLinks.terms) {
                    ValueRow(title: "Terms of use", showsChevron: true)
                }
                .buttonStyle(PressableStyle())
                RowDivider()
                ValueRow(title: "Version", value: version)
            }
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    /// Developer tools show in debug and TestFlight builds, never on the App Store.
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

enum AppLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Set CROWNS_PRIVACY_URL in Config/Crowns.xcconfig. Nil hides the link.
    static var privacy: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "CrownsPrivacyURL") as? String,
              raw.hasPrefix("https://") else { return nil }
        return URL(string: raw)
    }
}
