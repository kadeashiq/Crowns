import SwiftUI

/// Short confirmations: "Saved", "Moved to Wishlist".
@MainActor
@Observable
final class ToastCenter {
    private(set) var message: String?
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    func show(_ text: String) {
        hideTask?.cancel()
        withAnimation(Motion.standard) { message = text }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.standard) { self?.message = nil }
        }
    }
}

struct ToastOverlay: View {
    let center: ToastCenter

    var body: some View {
        VStack {
            Spacer()
            if let message = center.message {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .glassEffect(.regular, in: .capsule)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 28)
            }
        }
        .allowsHitTesting(false)
    }
}
