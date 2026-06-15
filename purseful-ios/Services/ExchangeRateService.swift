import Foundation

actor ExchangeRateService {
    static let shared = ExchangeRateService()

    private static let currencyCodes = ["USD", "EUR", "GBP", "PLN", "CHF", "JPY", "CAD", "AUD", "SEK", "NOK"]

    private var cachedRates: [String: Decimal] = [:]
    private var lastFetch: Date?
    private let cacheDuration: TimeInterval = 3600

    func rates(base: String) async -> [String: Decimal] {
        if let lastFetch, Date().timeIntervalSince(lastFetch) < cacheDuration, !cachedRates.isEmpty {
            return cachedRates
        }

        var rates: [String: Decimal] = [base: 1]
        if let fetched = await fetchRates(base: base) {
            rates.merge(fetched) { _, new in new }
            cachedRates = rates
            lastFetch = Date()
        } else if !cachedRates.isEmpty {
            return cachedRates
        }

        for code in Self.currencyCodes where rates[code] == nil {
            rates[code] = 1
        }
        cachedRates = rates
        return rates
    }

    func setManualRate(currency: String, rate: Decimal, base: String) {
        if cachedRates.isEmpty {
            cachedRates[base] = 1
        }
        cachedRates[currency] = rate
    }

    private func fetchRates(base: String) async -> [String: Decimal]? {
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=\(base)") else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ratesDict = json["rates"] as? [String: Double] else {
                return nil
            }
            var rates = ratesDict.mapValues { Decimal($0) }
            rates[base] = 1
            return rates
        } catch {
            return nil
        }
    }
}

enum CommonCurrencies {
    static let codes = ["USD", "EUR", "GBP", "PLN", "CHF", "JPY", "CAD", "AUD", "SEK", "NOK"]
}

enum ExchangeRateCache {
    private struct Payload: Codable {
        let baseCurrency: String
        let rates: [String: Double]
        let fetchedAt: Date
    }

    static func save(_ rates: [String: Decimal], base: String) {
        let payload = Payload(
            baseCurrency: base,
            rates: rates.mapValues { NSDecimalNumber(decimal: $0).doubleValue },
            fetchedAt: Date()
        )
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: AppConstants.exchangeRatesCacheKey)
        }
    }

    static func load(for base: String) -> [String: Decimal] {
        guard let data = UserDefaults.standard.data(forKey: AppConstants.exchangeRatesCacheKey),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.baseCurrency == base else {
            return fallbackRates(base: base)
        }
        var rates = payload.rates.mapValues { Decimal($0) }
        rates[base] = 1
        return rates
    }

    static func fallbackRates(base: String) -> [String: Decimal] {
        var rates = [base: Decimal(1)]
        for code in CommonCurrencies.codes where code != base {
            rates[code] = 1
        }
        return rates
    }
}
