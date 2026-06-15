import Foundation
import SwiftData
import WidgetKit

enum WidgetDataSync {
    private static let suiteName = AppConstants.appGroupIdentifier
    private static let snapshotFileName = "widget-snapshot.json"

    struct RecentTransactionSnapshot: Codable {
        let title: String
        let amount: String
        let date: Date
    }

    struct Snapshot: Codable {
        var accountName: String
        var accountBalance: String
        var accountCurrency: String
        var budgetSpent: String
        var budgetLimit: String
        var todaySpend: String
        var recentTransactions: [RecentTransactionSnapshot]
        var updatedAt: Date
    }

    @MainActor
    static func update(
        accounts: [Account],
        transactions: [Transaction],
        budgets: [Budget],
        exchangeRates: [String: Decimal]? = nil
    ) {
        let baseCurrency = AppSettings.shared.baseCurrency
        let rates = exchangeRates ?? ExchangeRateCache.load(for: baseCurrency)
        let visibleAccounts = accounts.filter { !$0.isHidden }
        let primary = visibleAccounts.first

        let accountName = primary?.name ?? "No Account"
        let accountCurrency = primary?.currency ?? baseCurrency
        let accountBalance: String
        if let primary {
            let balance = BalanceCalculator.currentBalance(for: primary, transactions: transactions)
            accountBalance = NSDecimalNumber(decimal: balance).stringValue
        } else {
            accountBalance = "0"
        }

        let budgetSpent: String
        let budgetLimit: String
        if let budget = budgets.first {
            let spent = BudgetService.spentAmount(
                budget: budget,
                transactions: transactions,
                baseCurrency: baseCurrency,
                exchangeRates: rates
            )
            budgetSpent = NSDecimalNumber(decimal: spent).stringValue
            budgetLimit = NSDecimalNumber(decimal: BudgetService.effectiveLimit(budget: budget)).stringValue
        } else {
            budgetSpent = "0"
            budgetLimit = "0"
        }

        let today = Calendar.current.startOfDay(for: Date())
        let todaySpend = BalanceCalculator.totalExpenses(
            transactions: transactions,
            from: today,
            through: Date(),
            baseCurrency: baseCurrency,
            exchangeRates: rates
        )

        let recent = transactions
            .filter { !$0.isSplitChild }
            .prefix(5)
            .map {
                RecentTransactionSnapshot(
                    title: $0.title.isEmpty ? ($0.category?.name ?? "Transaction") : $0.title,
                    amount: NSDecimalNumber(decimal: $0.amount).stringValue,
                    date: $0.date
                )
            }

        let snapshot = Snapshot(
            accountName: accountName,
            accountBalance: accountBalance,
            accountCurrency: accountCurrency,
            budgetSpent: budgetSpent,
            budgetLimit: budgetLimit,
            todaySpend: NSDecimalNumber(decimal: todaySpend).stringValue,
            recentTransactions: Array(recent),
            updatedAt: Date()
        )

        persist(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func persist(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }

        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: suiteName
        ) {
            let fileURL = container.appendingPathComponent(snapshotFileName)
            try? data.write(to: fileURL, options: .atomic)
        }

        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.set(data, forKey: snapshotFileName)
        }
    }

    static func readAccountBalance() -> (name: String, balance: Decimal, currency: String) {
        let snapshot = loadSnapshot()
        return (
            snapshot.accountName,
            Decimal(string: snapshot.accountBalance) ?? 0,
            snapshot.accountCurrency
        )
    }

    static func readBudgetProgress() -> (spent: Decimal, limit: Decimal) {
        let snapshot = loadSnapshot()
        return (
            Decimal(string: snapshot.budgetSpent) ?? 0,
            Decimal(string: snapshot.budgetLimit) ?? 0
        )
    }

    static func readTodaySpend() -> Decimal {
        Decimal(string: loadSnapshot().todaySpend) ?? 0
    }

    static func readRecentTransactions() -> [RecentTransactionSnapshot] {
        loadSnapshot().recentTransactions
    }

    private static func loadSnapshot() -> Snapshot {
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: suiteName
        ) {
            let fileURL = container.appendingPathComponent(snapshotFileName)
            if let data = try? Data(contentsOf: fileURL),
               let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
                return snapshot
            }
        }

        if let defaults = UserDefaults(suiteName: suiteName),
           let data = defaults.data(forKey: snapshotFileName),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            return snapshot
        }

        return Snapshot(
            accountName: "Purseful",
            accountBalance: "0",
            accountCurrency: "USD",
            budgetSpent: "0",
            budgetLimit: "0",
            todaySpend: "0",
            recentTransactions: [],
            updatedAt: .distantPast
        )
    }
}
