import SwiftUI
import UIKit

struct OnboardingPage: Identifiable {
    let image: String
    var step: String? = nil
    let title: String
    let message: String

    var id: String { image }

    static let tour = [
        OnboardingPage(image: "onboarding-grid", title: "Every watch. One place.", message: "The ones you own and the ones you want."),
        OnboardingPage(image: "onboarding-detail", title: "Know every detail", message: "Photo, price and specs, one tap away."),
        OnboardingPage(image: "onboarding-boxes", title: "Sort it your way", message: "Make boxes. Drag them into order."),
    ]

    static let safari = [
        OnboardingPage(image: "onboarding-safari-menu", step: "Step 1 of 3", title: "Find a watch", message: "In Safari, tap ••• then Share."),
        OnboardingPage(image: "onboarding-safari-share", step: "Step 2 of 3", title: "Tap Crowns", message: "Not there? Tap More and add it."),
        OnboardingPage(image: "onboarding-safari-save", step: "Step 3 of 3", title: "Pick a cover", message: "We read the listing. You tap Save."),
    ]
}

/// Swipeable pages of real screenshots, shown on first launch and from Settings.
struct OnboardingView: View {
    let pages: [OnboardingPage]
    var finishTitle = "Done"
    var canSkip = false
    let onFinish: () -> Void

    @State private var index = 0

    init(pages: [OnboardingPage], finishTitle: String = "Done", canSkip: Bool = false, onFinish: @escaping () -> Void) {
        self.pages = pages
        self.finishTitle = finishTitle
        self.canSkip = canSkip
        self.onFinish = onFinish
        UIPageControl.appearance().currentPageIndicatorTintColor = Theme.uiInk
        UIPageControl.appearance().pageIndicatorTintColor = Theme.uiInk.withAlphaComponent(0.2)
    }

    private var isLast: Bool { index == pages.count - 1 }

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { offset, page in
                pageView(page).tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        .background(Theme.canvas)
        .fadingBar(.top) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish)
                    .buttonStyle(.pill(.quiet, size: .small))
                    .opacity(canSkip && !isLast ? 1 : 0)
                    .disabled(!canSkip || isLast)
            }
            .padding(.horizontal, Space.sm)
            .padding(.top, Space.lg)
        }
        .fadingBar(.bottom) {
            Button {
                if isLast {
                    onFinish()
                } else {
                    withAnimation { index += 1 }
                }
            } label: {
                Text(isLast ? finishTitle : "Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pill())
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.sm)
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
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
                if let step = page.step {
                    Text(step)
                        .font(Typeface.micro)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Text(page.title)
                    .font(Typeface.title)
                    .foregroundStyle(Theme.ink)
                Text(page.message)
                    .font(Typeface.body)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Space.lg)
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.xxl)
    }
}
