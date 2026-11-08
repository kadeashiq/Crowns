import Foundation
import StoreKit
import SwiftData

/// Crowns Pro: free for 3 watches, then £1.99 a month or £14.99 a year.
///
/// The entitlement is read from StoreKit and mirrored into the App Group so
/// the share extension knows immediately, even before StoreKit answers.
@MainActor
@Observable
final class ProStore {
    static let shared = ProStore()

    static let monthlyID = "crowns.pro.monthly"
    static let yearlyID = "crowns.pro.yearly"
    static let productIDs = [monthlyID, yearlyID]
    static let freeLimit = 3
    private static let cacheKey = "isPro"

    private(set) var products: [Product] = []
    private(set) var isPro: Bool = AppGroup.defaults.bool(forKey: ProStore.cacheKey)
    private(set) var loadedProducts = false

    @ObservationIgnored private var updates: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
    }

    func load() async {
        if products.isEmpty {
            let fetched = (try? await Product.products(for: Self.productIDs)) ?? []
            products = fetched.sorted { $0.price < $1.price }
        }
        loadedProducts = true
        await refresh()
    }

    func refresh() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Self.productIDs.contains(t.productID), t.revocationDate == nil {
                pro = true
            }
        }
        isPro = pro
        AppGroup.defaults.set(pro, forKey: Self.cacheKey)
    }

    enum Outcome { case purchased, cancelled, pending, failed }

    func purchase(_ product: Product) async -> Outcome {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return .failed }
                await transaction.finish()
                await refresh()
                return .purchased
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    func restore() async -> Bool {
        try? await AppStore.sync()
        await refresh()
        return isPro
    }

    func watchCount(in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<Watch>())) ?? 0
    }

    /// Saving another watch is free up to the limit.
    func canAddWatch(in context: ModelContext) -> Bool {
        isPro || watchCount(in: context) < Self.freeLimit
    }
}

extension Product {
    var isYearly: Bool { subscription?.subscriptionPeriod.unit == .year }

    /// "£14.99 a year".
    var priceLine: String {
        "\(displayPrice) \(isYearly ? "a year" : "a month")"
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
