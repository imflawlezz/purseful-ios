import Foundation
import SwiftData
import WidgetKit

enum WidgetDataSync {
    private static let suiteName = AppConstants.appGroupIdentifier
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

    struct NextPaymentSnapshot: Codable, Hashable {
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
    }

    @MainActor
    static func sync(using repository: DataRepositoryProtocol) {
        let accounts = (try? repository.fetch(
            FetchDescriptor<Account>(sortBy: [SortDescriptor(\.sortOrder)])
        )) ?? []
        let transactions = (try? repository.fetch(
            FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )) ?? []
        let budgets = (try? repository.fetch(
            FetchDescriptor<Budget>(sortBy: [SortDescriptor(\.name)])
        )) ?? []
        let payments = (try? repository.fetch(
            FetchDescriptor<PlannedPayment>(sortBy: [SortDescriptor(\.nextDueDate)])
        )) ?? []
        let goals = (try? repository.fetch(
            FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.name)])
        )) ?? []
        update(
            accounts: accounts,
            transactions: transactions,
            budgets: budgets,
            plannedPayments: payments,
            goals: goals
        )
    }

    @MainActor
    static func update(
        accounts: [Account],
        transactions: [Transaction],
        budgets: [Budget],
        plannedPayments: [PlannedPayment] = [],
        goals: [Goal] = [],
        exchangeRates: [String: Decimal]? = nil
    ) {
        let baseCurrency = AppSettings.shared.baseCurrency
        let rates = exchangeRates ?? ExchangeRateCache.load(for: baseCurrency)
        let visibleAccounts = accounts
            .filter { !$0.isHidden }
            .sorted { $0.sortOrder < $1.sortOrder }

        let accountSnapshots = visibleAccounts.map { account in
            AccountSnapshot(
                id: account.id.uuidString,
                name: account.name,
                balance: decimalString(BalanceCalculator.currentBalance(for: account, transactions: transactions)),
                currency: account.currency
            )
        }

        let budgetSnapshots = budgets.map { budget -> BudgetSnapshot in
            let spent = BudgetService.spentAmount(
                budget: budget,
                transactions: transactions,
                baseCurrency: baseCurrency,
                exchangeRates: rates
            )
            let limit = BudgetService.effectiveLimit(budget: budget)
            let remaining = max(0, limit - spent)
            return BudgetSnapshot(
                id: budget.id.uuidString,
                name: budget.name,
                period: budget.period.displayName,
                spent: decimalString(spent),
                limit: decimalString(limit),
                remaining: decimalString(remaining)
            )
        }

        let goalSnapshots = goals
            .filter { !$0.isCompleted }
            .map { goal in
                GoalSnapshot(
                    id: goal.id.uuidString,
                    name: goal.name,
                    current: decimalString(goal.currentAmount),
                    target: decimalString(goal.targetAmount),
                    colorHex: goal.colorHex
                )
            }

        let today = Calendar.current.startOfDay(for: Date())
        let todaySpend = BalanceCalculator.totalExpenses(
            transactions: transactions,
            from: today,
            through: Date(),
            baseCurrency: baseCurrency,
            exchangeRates: rates
        )

        let netWorth = BalanceCalculator.netWorth(
            accounts: accounts,
            transactions: transactions,
            baseCurrency: baseCurrency,
            exchangeRates: rates
        )

        let recent = transactions
            .filter { !$0.isSplitChild }
            .sorted { $0.date > $1.date }
            .prefix(6)
            .map { tx in
                let rawTitle = tx.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let categoryName = tx.category?.name
                let title: String
                if rawTitle.isEmpty {
                    title = categoryName?.localizedDisplayName ?? tx.type.displayName
                } else if let categoryName,
                          rawTitle.localizedCaseInsensitiveCompare(categoryName) == .orderedSame {
                    title = categoryName.localizedDisplayName
                } else {
                    title = rawTitle
                }
                return RecentTransactionSnapshot(
                    title: title,
                    amount: decimalString(tx.amount),
                    date: tx.date,
                    type: tx.type.rawValue,
                    categoryColorHex: tx.category?.colorHex
                        ?? tx.account?.colorHex
                        ?? "#8E8E93"
                )
            }

        let upcomingPayments: [NextPaymentSnapshot] = plannedPayments
            .filter { $0.isActive && !PlannedPaymentSchedule.isPaidInCurrentPeriod($0) }
            .sorted { $0.nextDueDate < $1.nextDueDate }
            .prefix(8)
            .map { payment in
                NextPaymentSnapshot(
                    name: payment.name,
                    amount: decimalString(payment.amount),
                    currency: payment.account?.currency ?? baseCurrency,
                    dueDate: payment.nextDueDate,
                    isOverdue: payment.isOverdue
                )
            }

        let snapshot = Snapshot(
            accentColorHex: AppSettings.shared.accentColorHex,
            baseCurrency: baseCurrency,
            accounts: accountSnapshots,
            budgets: budgetSnapshots,
            goals: goalSnapshots,
            todaySpend: decimalString(todaySpend),
            netWorth: decimalString(netWorth),
            recentTransactions: Array(recent),
            upcomingPayments: Array(upcomingPayments),
            updatedAt: Date()
        )

        persist(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
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

    // MARK: - Readers

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
}
