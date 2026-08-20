import Foundation

enum WidgetDataSync {
    private static let suiteName = "group.dev.imflawlezz.purseful-ios"
    private static let snapshotFileName = "widget-snapshot.json"
    static let staleAfter: TimeInterval = 60 * 60 * 24

    struct AccountSnapshot: Codable, Identifiable, Hashable {
        let id: String
        let name: String
        let balance: String
        let currency: String
    }

    struct BudgetSnapshot: Codable, Identifiable, Hashable {
        let id: String
        let name: String
        let period: String
        let spent: String
        let limit: String
        let remaining: String
    }

    struct GoalSnapshot: Codable, Identifiable, Hashable {
        let id: String
        let name: String
        let current: String
        let target: String
        let colorHex: String
    }

    struct RecentTransactionSnapshot: Codable, Hashable {
        let title: String
        let amount: String
        let date: Date
        let type: String
        let categoryColorHex: String
    }

    struct NextPaymentSnapshot: Codable, Hashable, Identifiable {
        var id: String { "\(name)-\(dueDate.timeIntervalSince1970)-\(amount)" }
        let name: String
        let amount: String
        let currency: String
        let dueDate: Date
        let isOverdue: Bool
    }

    struct Snapshot: Codable {
        var accentColorHex: String
        var baseCurrency: String
        var accounts: [AccountSnapshot]
        var budgets: [BudgetSnapshot]
        var goals: [GoalSnapshot]
        var todaySpend: String
        var netWorth: String
        var recentTransactions: [RecentTransactionSnapshot]
        var upcomingPayments: [NextPaymentSnapshot]
        var updatedAt: Date

        var nextPayment: NextPaymentSnapshot? { upcomingPayments.first }

        var isStale: Bool {
            Date().timeIntervalSince(updatedAt) > WidgetDataSync.staleAfter
                || updatedAt == .distantPast
        }

        func account(id: String?) -> AccountSnapshot? {
            if let id, let match = accounts.first(where: { $0.id == id }) {
                return match
            }
            return accounts.first
        }

        func budget(id: String?) -> BudgetSnapshot? {
            if let id, let match = budgets.first(where: { $0.id == id }) {
                return match
            }
            return budgets.first
        }

        func balancesLayout(primaryID: String?) -> (primary: AccountSnapshot?, secondary: [AccountSnapshot]) {
            let primary = account(id: primaryID)
            let secondary = accounts
                .filter { $0.id != primary?.id }
                .prefix(4)
            return (primary, Array(secondary))
        }

        func decimal(_ raw: String) -> Decimal {
            Decimal(string: raw) ?? 0
        }
    }

    static func loadSnapshot() -> Snapshot {
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

        return emptySnapshot()
    }

    static func emptySnapshot() -> Snapshot {
        Snapshot(
            accentColorHex: "#FF3B30",
            baseCurrency: "USD",
            accounts: [],
            budgets: [],
            goals: [],
            todaySpend: "0",
            netWorth: "0",
            recentTransactions: [],
            upcomingPayments: [],
            updatedAt: .distantPast
        )
    }

    static func placeholderSnapshot() -> Snapshot {
        let due = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return Snapshot(
            accentColorHex: "#FF3B30",
            baseCurrency: "PLN",
            accounts: [
                AccountSnapshot(id: "a1", name: "Card", balance: "452.77", currency: "PLN"),
                AccountSnapshot(id: "a2", name: "Wallet", balance: "120.00", currency: "PLN"),
                AccountSnapshot(id: "a3", name: "Savings", balance: "3200.00", currency: "PLN"),
                AccountSnapshot(id: "a4", name: "EUR", balance: "80.00", currency: "EUR"),
                AccountSnapshot(id: "a5", name: "Cash", balance: "45.00", currency: "PLN")
            ],
            budgets: [
                BudgetSnapshot(
                    id: "b1",
                    name: "Food",
                    period: "Monthly",
                    spent: "206.37",
                    limit: "550",
                    remaining: "343.63"
                )
            ],
            goals: [],
            todaySpend: "48.40",
            netWorth: "458.59",
            recentTransactions: [],
            upcomingPayments: [
                NextPaymentSnapshot(
                    name: "iCloud+",
                    amount: "4.99",
                    currency: "PLN",
                    dueDate: due,
                    isOverdue: false
                ),
                NextPaymentSnapshot(
                    name: "Rent",
                    amount: "2800",
                    currency: "PLN",
                    dueDate: Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? due,
                    isOverdue: false
                )
            ],
            updatedAt: Date()
        )
    }
}
