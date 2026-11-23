import SwiftUI
import SwiftData

/// The first run, in the shape of Prayde's: a welcome, a few choices, then
/// the features. Each step pushes like any navigation screen.
struct WelcomeFlow: View {
    /// Called at the end with the box to open on, if one was picked.
    let onFinish: (_ startBoxID: UUID?) -> Void

    @State private var path: [Step] = []
    @State private var startBoxID: UUID?

    enum Step: Int, Hashable {
        case welcome, iCloud, links, start, icon, features

        /// The steps with progress dots; the features come after.
        static let setup: [Step] = [.welcome, .iCloud, .links, .start, .icon]
    }

    var body: some View {
        NavigationStack(path: $path) {
            page(.welcome)
                .navigationDestination(for: Step.self, destination: page)
        }
        .tint(Theme.ink)
    }

    private func advance(from step: Step) {
        if let next = Step(rawValue: step.rawValue + 1) {
            path.append(next)
        } else {
            onFinish(startBoxID)
        }
    }

    @ViewBuilder
    private func page(_ step: Step) -> some View {
        let next = { advance(from: step) }
        switch step {
        case .welcome: WelcomePage(next: next)
        case .iCloud: ICloudPage(next: next)
        case .links: LinksPage(status: AppleIntelligence.status, next: next)
        case .start: StartBoxPage(selection: $startBoxID, next: next)
        case .icon: IconPage(next: next)
        case .features: FeaturesPage(next: next)
        }
    }
}

// MARK: - Shared pieces

/// A setup page: dots along the top, content in the middle, its buttons at the foot.
private struct StepPage<Content: View, Buttons: View>: View {
    let step: WelcomeFlow.Step
    @ViewBuilder var content: () -> Content
    @ViewBuilder var buttons: () -> Buttons

    var body: some View {
        ScrollView {
            content()
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.xl)
                .padding(.bottom, Space.xl)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.canvas)
        .fadingBar(.bottom) {
            VStack(spacing: Space.xxs) {
                buttons()
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.sm)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                StepDots(step: step)
            }
        }
    }
}

/// Where the setup has got to: a long dash for this step, dots for the rest.
private struct StepDots: View {
    let step: WelcomeFlow.Step

    var body: some View {
        let steps = WelcomeFlow.Step.setup
        let current = steps.firstIndex(of: step) ?? 0
        HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Theme.ink : Theme.ink.opacity(0.18))
                    .frame(width: index == current ? 24 : 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(steps.count)")
    }
}

/// An optional glyph in a black circle, a title and one line under it, centred.
private struct StepTitle: View {
    var icon: String?
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Space.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.onInk)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Theme.ink))
                    .elevation(.mid)
                    .padding(.bottom, Space.xs)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(Typeface.body)
                .foregroundStyle(Theme.inkSecondary)
                .lineSpacing(2)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
    }
}

private struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.pill())
    }
}

// MARK: - Welcome

private struct WelcomePage: View {
    let next: () -> Void

    /// Where each name sits in its band, as a share of the band's width and height.
    private static let above: [(String, CGFloat, CGFloat)] = [
        ("Rolex", 0.20, 0.06), ("Omega", 0.74, 0.12), ("Grand Seiko", 0.46, 0.30),
        ("Tudor", 0.14, 0.50), ("Cartier", 0.82, 0.46), ("Nomos", 0.60, 0.66),
        ("Longines", 0.26, 0.82), ("Patek Philippe", 0.72, 0.94), ("IWC", 0.08, 0.98),
    ]
    private static let below: [(String, CGFloat, CGFloat)] = [
        ("Seiko", 0.14, 0.04), ("Jaeger-LeCoultre", 0.54, 0.10), ("Zenith", 0.88, 0.02),
        ("Breitling", 0.28, 0.30), ("Oris", 0.88, 0.34), ("Christopher Ward", 0.60, 0.50),
        ("Sinn", 0.10, 0.60), ("Panerai", 0.82, 0.74), ("Hamilton", 0.36, 0.78),
        ("Vacheron Constantin", 0.56, 0.98), ("Lorier", 0.12, 0.96),
    ]

    var body: some View {
        StepPage(step: .welcome) {
            VStack(spacing: Space.lg) {
                names(Self.above)
                VStack(spacing: Space.xs) {
                    Image(AppIcons.preview(UIApplication.shared.alternateIconName))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 104, height: 104)
                        .clipShape(.rect(cornerRadius: 24, style: .continuous))
                        .elevation(.high)
                        .padding(.bottom, Space.md)
                        .accessibilityHidden(true)
                    Text("Welcome to")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Crowns")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Every watch you own and want, in one place.")
                        .font(Typeface.body)
                        .foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Space.xxs)
                }
                names(Self.below)
            }
        } buttons: {
            PrimaryButton(title: "Let's get started", action: next)
        }
    }

    private func names(_ names: [(String, CGFloat, CGFloat)]) -> some View {
        GeometryReader { proxy in
            ForEach(names, id: \.0) { name, x, y in
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkTertiary.opacity(0.45))
                    .fixedSize()
                    .position(x: proxy.size.width * x, y: proxy.size.height * y)
            }
        }
        .frame(height: 120)
        .accessibilityHidden(true)
    }
}

// MARK: - iCloud

private struct ICloudPage: View {
    let next: () -> Void

    var body: some View {
        StepPage(step: .iCloud) {
            StepTitle(
                icon: "icloud.fill",
                title: "Keep them in iCloud",
                subtitle: "Your watches stay in your own iCloud, so they come back on a new iPhone. Only you can see them."
            )
            .padding(.top, Space.xxl)
        } buttons: {
            PrimaryButton(title: "Use iCloud") { choose(true) }
            Button("Not now") { choose(false) }
                .buttonStyle(.pill(.quiet))
        }
    }

    private func choose(_ sync: Bool) {
        AppGroup.defaults.set(sync, forKey: SharedKeys.iCloudSync)
        next()
    }
}

// MARK: - Links

/// How watches get in: from Safari with Apple Intelligence, by hand without it.
private struct LinksPage: View {
    let status: AppleIntelligence.Status
    let next: () -> Void

    private static let steps = [
        ("onboarding-safari-menu", "Tap ••• then Share"),
        ("onboarding-safari-share", "Tap Crowns"),
        ("onboarding-safari-save", "Pick a cover"),
    ]

    var body: some View {
        StepPage(step: .links) {
            VStack(spacing: Space.xl) {
                title
                if status == .available {
                    HStack(alignment: .top, spacing: Space.sm) {
                        ForEach(Self.steps, id: \.0) { image, caption in
                            VStack(spacing: Space.xs) {
                                Image(image)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(.rect(cornerRadius: Radius.md, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                            .strokeBorder(Theme.hairline, lineWidth: 1)
                                    )
                                    .elevation(.low)
                                    .accessibilityHidden(true)
                                Text(caption)
                                    .font(Typeface.micro)
                                    .foregroundStyle(Theme.inkSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
            }
            .padding(.top, status == .available ? 0 : Space.xxl)
        } buttons: {
            PrimaryButton(title: "Continue", action: next)
        }
    }

    @ViewBuilder
    private var title: some View {
        switch status {
        case .available:
            StepTitle(
                icon: "apple.intelligence",
                title: "Save from Safari",
                subtitle: "Share a watch's page to Crowns and it brings the photos, price and specs. Apple Intelligence fills any gaps, on your iPhone."
            )
        case .turnedOff:
            StepTitle(
                icon: "apple.intelligence",
                title: "Turn on Apple Intelligence",
                subtitle: "Crowns uses it to save watches from Safari. Turn it on in Settings, under Apple Intelligence & Siri. Until then, add watches yourself."
            )
        case .gettingReady:
            StepTitle(
                icon: "apple.intelligence",
                title: "Almost ready",
                subtitle: "Apple Intelligence is still downloading. Once it's done, you can save watches from Safari. Until then, add watches yourself."
            )
        case .notSupported:
            StepTitle(
                icon: "square.and.pencil",
                title: "Add watches yourself",
                subtitle: "Saving from Safari needs an iPhone with Apple Intelligence. You can add any watch by hand: its details, a photo, and which box."
            )
        }
    }
}

// MARK: - Start box

private struct StartBoxPage: View {
    @Binding var selection: UUID?
    let next: () -> Void

    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]
    @State private var isAddingBox = false

    private func look(_ box: Box) -> (icon: String, detail: String) {
        switch box.seedKey {
        case BoxSeeder.collectionKey: ("checkmark.seal", "The watches you own")
        case BoxSeeder.wishlistKey: ("heart", "The ones you want")
        default: ("square.grid.2x2", "Your own box")
        }
    }

    var body: some View {
        StepPage(step: .start) {
            VStack(spacing: Space.xl) {
                StepTitle(
                    title: "Where do you want to start?",
                    subtitle: "Crowns opens on this box. Add your own, like Grails or Vintage, and change them any time."
                )
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.sm), GridItem(.flexible(), spacing: Space.sm)], spacing: Space.sm) {
                    ForEach(boxes) { box in
                        card(box)
                    }
                }
                Button {
                    isAddingBox = true
                } label: {
                    Label("Add a box", systemImage: "plus")
                }
                .buttonStyle(.pill(.secondary, size: .small))
            }
            .padding(.top, Space.lg)
        } buttons: {
            PrimaryButton(title: "Continue") {
                if let selection {
                    AppGroup.defaults.set(selection.uuidString, forKey: SharedKeys.lastBoxID)
                }
                next()
            }
        }
        .onAppear {
            if selection == nil {
                selection = (boxes.first { $0.seedKey == BoxSeeder.collectionKey } ?? boxes.first)?.id
            }
        }
        .sheet(isPresented: $isAddingBox) {
            BoxEditorSheet(box: nil) { saved in
                isAddingBox = false
                if let saved { selection = saved.id }
            }
            .crownsSheet()
        }
    }

    private func card(_ box: Box) -> some View {
        let selected = selection == box.id
        let look = look(box)
        return Button {
            Haptics.tick()
            selection = box.id
        } label: {
            VStack(spacing: Space.xs) {
                Image(systemName: look.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(selected ? Theme.onInk : Theme.ink)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(selected ? Theme.ink : Theme.well))
                    .padding(.bottom, Space.xxs)
                Text(box.name)
                    .font(Typeface.heading)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(look.detail)
                    .font(Typeface.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, Space.lg)
            .padding(.horizontal, Space.sm)
            .frame(maxWidth: .infinity)
            .surface(radius: Radius.lg, elevation: selected ? .mid : .low)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(Theme.ink, lineWidth: selected ? 2 : 0)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Icon

private struct IconPage: View {
    let next: () -> Void

    @State private var current = UIApplication.shared.alternateIconName

    var body: some View {
        StepPage(step: .icon) {
            VStack(spacing: Space.xl) {
                StepTitle(title: "Pick your icon", subtitle: "You can change it in Settings.")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.md), count: 3), spacing: Space.lg) {
                    ForEach(AppIcons.all, id: \.self) { name in
                        icon(name)
                    }
                }
            }
            .padding(.top, Space.lg)
        } buttons: {
            PrimaryButton(title: "Continue", action: next)
        }
    }

    private func icon(_ name: String?) -> some View {
        let selected = current == name
        return Button {
            guard !selected else { return }
            Haptics.tick()
            Task {
                try? await UIApplication.shared.setAlternateIconName(name)
                current = UIApplication.shared.alternateIconName
            }
        } label: {
            VStack(spacing: Space.xs) {
                Image(AppIcons.preview(name))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                    .clipShape(.rect(cornerRadius: 19, style: .continuous))
                    .elevation(selected ? .mid : .low)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .strokeBorder(Theme.ink, lineWidth: selected ? 2 : 0)
                    )
                Text(AppIcons.title(name))
                    .font(Typeface.label)
                    .foregroundStyle(selected ? Theme.ink : Theme.inkSecondary)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(AppIcons.title(name))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Features

private struct FeaturesPage: View {
    let next: () -> Void

    @State private var index = 0
    private let pages = OnboardingPage.tour

    init(next: @escaping () -> Void) {
        self.next = next
        UIPageControl.appearance().currentPageIndicatorTintColor = Theme.uiInk
        UIPageControl.appearance().pageIndicatorTintColor = Theme.uiInk.withAlphaComponent(0.2)
    }

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { offset, page in
                slide(page).tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        .background(Theme.canvas)
        .fadingBar(.bottom) {
            PrimaryButton(title: index == pages.count - 1 ? "Get started" : "Next") {
                if index == pages.count - 1 {
                    next()
                } else {
                    withAnimation { index += 1 }
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.sm)
        }
        .navigationTitle("Features")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip", action: next)
            }
        }
    }

    private func slide(_ page: OnboardingPage) -> some View {
        VStack(spacing: Space.lg) {
            Image(page.image)
                .resizable()
                .scaledToFit()
                .clipShape(.rect(cornerRadius: Radius.xl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
                .elevation(.high)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)
            VStack(spacing: Space.xs) {
                Text(page.title)
                    .font(Typeface.title)
                    .foregroundStyle(Theme.ink)
                Text(page.message)
                    .font(Typeface.body)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.sm)
        .padding(.bottom, 120)
    }
}
