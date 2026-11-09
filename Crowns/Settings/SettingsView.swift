import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(SyncMonitor.self) private var sync

    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]

    @AppStorage(SharedKeys.iCloudSync, store: AppGroup.defaults) private var iCloudSync = true
    @State private var editingBox: BoxEditRequest?
    @State private var showBoxOrder = false
    @State private var guide: Guide?
    @State private var currentIcon = UIApplication.shared.alternateIconName

    private enum Guide: String, Identifiable {
        case tour, safari

        var id: String { rawValue }
        var pages: [OnboardingPage] { self == .tour ? OnboardingPage.tour : OnboardingPage.safari }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                hero
                iconSection
                iCloudSection
                boxesSection
                helpSection
                aboutSection
            }
            .padding(.horizontal, Space.md)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xl)
        }
        .scrollIndicators(.hidden)
        .fadingBar(.top) {
            SheetHeader(title: "Settings")
        }
        .background(Theme.canvas)
        .sheet(isPresented: $showBoxOrder) {
            BoxOrderSheet()
                .presentationDetents([.medium, .large])
                .crownsSheet()
        }
        .sheet(item: $editingBox) { request in
            BoxEditorSheet(box: request.box) { _ in editingBox = nil }
                .crownsSheet()
        }
        .sheet(item: $guide) { guide in
            OnboardingView(pages: guide.pages) { self.guide = nil }
                .crownsSheet()
        }
        .task {
            await sync.checkAccount()
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(spacing: Space.xxs) {
            Image(AppIcons.preview(currentIcon))
                .resizable()
                .frame(width: 88, height: 88)
                .elevation(.mid)
                .padding(.bottom, Space.xs)
                .accessibilityHidden(true)
            Text("Crowns")
                .font(Typeface.title)
                .foregroundStyle(Theme.ink)
            Text("Version \(version)")
                .font(Typeface.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.vertical, Space.xs)
    }

    private var iconSection: some View {
        FormSection(title: "App icon", padding: Space.sm) {
            ScrollView(.horizontal) {
                HStack(spacing: Space.md) {
                    ForEach(AppIcons.all, id: \.self) { name in
                        iconTile(name)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    private func iconTile(_ name: String?) -> some View {
        let selected = name == currentIcon
        return Button {
            choose(name)
        } label: {
            VStack(spacing: Space.xs) {
                Image(AppIcons.preview(name))
                    .resizable()
                    .frame(width: 64, height: 64)
                    .padding(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.ink, lineWidth: selected ? 2 : 0)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Theme.onInk, Theme.ink)
                                .offset(x: 3, y: 3)
                        }
                    }
                Text(AppIcons.title(name))
                    .font(Typeface.micro)
                    .foregroundStyle(selected ? Theme.ink : Theme.inkSecondary)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(AppIcons.title(name)) icon")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func choose(_ name: String?) {
        guard name != currentIcon else { return }
        Haptics.tick()
        Task {
            try? await UIApplication.shared.setAlternateIconName(name)
            currentIcon = UIApplication.shared.alternateIconName
        }
    }

    private var iCloudSection: some View {
        FormSection(title: "iCloud", footer: syncDetail, padding: 0) {
            ValueRow(title: "iCloud sync", icon: "icloud.fill") {
                Toggle("iCloud sync", isOn: $iCloudSync)
                    .labelsHidden()
                    .tint(Theme.ink)
                    .disabled(sync.account == .signedOut)
            }
        }
    }

    private var syncDetail: String {
        guard iCloudSync else { return "Stored on this device only." }
        switch sync.account {
        case .unknown: return "Checking iCloud…"
        case .signedOut: return "Sign in to iCloud to sync."
        case .restricted, .unavailable: return "iCloud is unavailable."
        case .available:
            if sync.syncing { return "Syncing…" }
            if sync.lastError != nil { return "Couldn't sync. Trying again soon." }
            if let last = sync.lastSync {
                return "Synced \(last.formatted(.relative(presentation: .named)))."
            }
            return "Synced across your devices."
        }
    }

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
                        ValueRow(title: "New box", icon: "plus")
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private func boxRow(_ box: Box) -> some View {
        Button { editingBox = BoxEditRequest(box: box) } label: {
            ValueRow(title: box.name, icon: "square.grid.2x2.fill", showsChevron: true) {
                Text("\(box.watches?.count ?? 0)").monospacedDigit()
            }
        }
        .buttonStyle(PressableStyle())
    }

    private var helpSection: some View {
        FormSection(title: "Help", padding: 0) {
            VStack(spacing: 0) {
                Button { guide = .tour } label: {
                    ValueRow(title: "How Crowns works", icon: "sparkles", showsChevron: true)
                }
                .buttonStyle(PressableStyle())
                RowDivider()
                Button { guide = .safari } label: {
                    ValueRow(title: "Save from Safari", icon: "safari.fill", showsChevron: true)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var aboutSection: some View {
        FormSection(title: "About", padding: 0) {
            VStack(spacing: 0) {
                if let privacy = AppLinks.privacy {
                    Link(destination: privacy) {
                        ValueRow(title: "Privacy", icon: "hand.raised.fill", showsChevron: true)
                    }
                    .buttonStyle(PressableStyle())
                    RowDivider()
                }
                Link(destination: AppLinks.terms) {
                    ValueRow(title: "Terms of use", icon: "doc.text.fill", showsChevron: true)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
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
