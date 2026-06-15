import Foundation

enum WidgetDataSync {
    private static let suiteName = "group.dev.imflawlezz.purseful-ios"
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
