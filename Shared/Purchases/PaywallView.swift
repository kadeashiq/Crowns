import SwiftUI
import StoreKit

/// Shown when saving a 4th watch. Short and plain.
struct PaywallView: View {
    let store: ProStore
    /// Called with true once Pro is active, false if the person backs out.
    let onFinish: (Bool) -> Void
    /// Set in the share extension: what to say if the purchase can't finish there.
    var fallbackNote: String? = nil
    /// Called instead of failing outright when a purchase can't complete here.
    var onCannotPurchase: (() -> Void)? = nil

    @State private var busy = false
    @State private var note = ""

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Image(systemName: "crown")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Theme.brass)
                Text("Crowns Pro")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("Keep more than \(ProStore.freeLimit) watches.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(.top, 8)

            VStack(spacing: 10) {
                if store.products.isEmpty {
                    if store.loadedProducts {
                        Text("Unavailable right now")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSecondary)
                    } else {
                        ProgressView().frame(height: 100)
                    }
                }
                ForEach(store.products, id: \.id) { product in
                    planButton(product)
                }
            }

            if !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 18) {
                Button("Restore") {
                    Task {
                        busy = true
                        let restored = await store.restore()
                        busy = false
                        if restored { onFinish(true) } else { note = "Nothing to restore" }
                    }
                }
                Link("Terms", destination: AppLinks.terms)
                if let privacy = AppLinks.privacy {
                    Link("Privacy", destination: privacy)
                }
            }
            .font(.footnote)
            .foregroundStyle(Theme.inkSecondary)

            Button("Not now") { onFinish(false) }
                .font(.subheadline)
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(24)
        .task { await store.load() }
    }

    @ViewBuilder
    private func planButton(_ product: Product) -> some View {
        let button = Button {
            Task { await buy(product) }
        } label: {
            HStack {
                Text(product.isYearly ? "Yearly" : "Monthly")
                    .font(.body.weight(.medium))
                Spacer()
                Text(product.priceLine)
                    .font(.body.monospacedDigit())
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
        }
        if product.isYearly {
            button.buttonStyle(.glassProminent).controlSize(.large).disabled(busy)
        } else {
            button.buttonStyle(.glass).controlSize(.large).disabled(busy)
        }
    }

    private func buy(_ product: Product) async {
        busy = true
        defer { busy = false }
        switch await store.purchase(product) {
        case .purchased:
            onFinish(true)
        case .cancelled:
            break
        case .pending:
            note = "Waiting for approval"
        case .failed:
            if let onCannotPurchase {
                onCannotPurchase()
            } else {
                note = fallbackNote ?? "Couldn't subscribe"
            }
        }
    }
}
