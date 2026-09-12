import Foundation
import SwiftData

/// App Group snapshot of account balances. Dashboard reads this instead of scanning all transactions.
enum BalanceCache {
    struct Snapshot: Codable {
        var updatedAt: Date
        var baseCurrency: String
        var balances: [String: String]
        var netWorth: String
    }

    private static let key = "balanceSnapshot.v1"

    static func load() -> Snapshot? {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    static func balancesMap() -> [UUID: Decimal] {
        guard let snapshot = load() else { return [:] }
        var result: [UUID: Decimal] = [:]
        result.reserveCapacity(snapshot.balances.count)
        for (idString, value) in snapshot.balances {
            guard let id = UUID(uuidString: idString),
                  let amount = Decimal(string: value) else { continue }
            result[id] = amount
        }
        return result
    }

    static func cachedNetWorth() -> Decimal? {
        guard let raw = load()?.netWorth else { return nil }
        return Decimal(string: raw)
    }

    static func save(
        balances: [UUID: Decimal],
        accounts: [Account],
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) {
        var encoded: [String: String] = [:]
        encoded.reserveCapacity(balances.count)
        for (id, amount) in balances {
            encoded[id.uuidString] = "\(amount)"
        }
        let netWorth = BalanceCalculator.netWorth(
            accounts: accounts,
            balances: balances,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )
        let snapshot = Snapshot(
            updatedAt: Date(),
            baseCurrency: baseCurrency,
            balances: encoded,
            netWorth: "\(netWorth)"
        )
        let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: key)
        }
    }

    static func clear() {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
        defaults.removeObject(forKey: key)
    }

    @MainActor
    static func rebuild(using repository: DataRepositoryProtocol, exchangeRates: [String: Decimal]? = nil) {
        let accounts = (try? repository.fetch(
            FetchDescriptor<Account>(sortBy: [SortDescriptor(\.sortOrder)])
        )) ?? []
        let transactions = (try? repository.fetch(
            FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )) ?? []
        let baseCurrency = AppSettings.shared.baseCurrency
        let rates = exchangeRates ?? ExchangeRateCache.load(for: baseCurrency)
        let balances = BalanceCalculator.balancesByAccountID(accounts: accounts, transactions: transactions)
        save(
            balances: balances,
            accounts: accounts,
            baseCurrency: baseCurrency,
            exchangeRates: rates
        )
    }
}
