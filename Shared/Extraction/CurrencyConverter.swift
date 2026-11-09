import Foundation

/// Converts foreign listings to pounds with daily ECB reference rates
/// (Frankfurter, no key needed), cached in the App Group for a day and
/// reused when offline.
enum CurrencyConverter {
    struct Rates: Codable {
        var date: String
        var fetchedAt: Date
        /// Units of each currency per £1.
        var perGBP: [String: Double]
    }

    private static let cacheKey = "fxRatesGBP"
    private static let maxAge: TimeInterval = 20 * 3600
    /// Older rates are only used when no newer ones can be had.
    private static let usableAge: TimeInterval = 7 * 24 * 3600
    private static let endpoints = [
        "https://api.frankfurter.dev/v1/latest?base=GBP",
        "https://api.frankfurter.app/latest?from=GBP",
    ]

    /// The price in whole pounds, or nil if there's no rate for its currency.
    static func toGBP(_ money: Money) async -> Money? {
        if money.isGBP { return money }
        guard let rates = await rates(), let rate = rates.perGBP[money.currency], rate > 0 else { return nil }
        let pounds = (NSDecimalNumber(decimal: money.amount).doubleValue / rate).rounded()
        return Money(amount: Decimal(pounds), currency: "GBP")
    }

    static func rates() async -> Rates? {
        let cached = load()
        let age = cached.map { Date().timeIntervalSince($0.fetchedAt) } ?? .infinity
        if age < maxAge { return cached }
        if age < usableAge {
            // Close enough for now. The next listing gets today's.
            Task.detached(priority: .utility) { _ = await refresh() }
            return cached
        }
        return await refresh() ?? cached
    }

    private static func refresh() async -> Rates? {
        guard let fresh = await fetch() else { return nil }
        save(fresh)
        return fresh
    }

    private struct Response: Decodable {
        var date: String
        var rates: [String: Double]
    }

    private static func fetch() async -> Rates? {
        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            var request = URLRequest(url: url, timeoutInterval: 6)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            guard let fetched = try? await URLSession.shared.data(for: request),
                  (fetched.1 as? HTTPURLResponse)?.statusCode == 200,
                  let decoded = try? JSONDecoder().decode(Response.self, from: fetched.0),
                  !decoded.rates.isEmpty else { continue }
            return Rates(date: decoded.date, fetchedAt: Date(), perGBP: decoded.rates)
        }
        return nil
    }

    private static func load() -> Rates? {
        guard let data = AppGroup.defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(Rates.self, from: data)
    }

    private static func save(_ rates: Rates) {
        if let data = try? JSONEncoder().encode(rates) {
            AppGroup.defaults.set(data, forKey: cacheKey)
        }
    }
}
