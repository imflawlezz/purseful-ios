import Foundation
import SwiftData

enum DailySpendLookback: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case thirtyDays = 30
    case ninetyDays = 90

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .sevenDays: String(localized: "7 days")
        case .thirtyDays: String(localized: "30 days")
        case .ninetyDays: String(localized: "90 days")
        }
    }
}

enum DailySpendCalculator {
    static func categoryMatchesSelection(_ category: Category?, selectedIDs: Set<UUID>) -> Bool {
        guard let category, !selectedIDs.isEmpty else { return false }
        if selectedIDs.contains(category.id) { return true }

        var ancestor = category.parent
        while let current = ancestor {
            if selectedIDs.contains(current.id) { return true }
            ancestor = current.parent
        }
        return false
    }

    static func selectedCategoryNames(_ categories: [Category], selectedIDs: Set<UUID>) -> [String] {
        guard !selectedIDs.isEmpty else { return [] }

        var names: [String] = []
        for root in expenseRootCategories(from: categories) {
            if selectedIDs.contains(root.id), root.isUserSelectable {
                names.append(root.name.localizedDisplayName)
            }
            for child in expenseChildCategories(of: root) where selectedIDs.contains(child.id) {
                names.append(child.name.localizedDisplayName)
            }
        }
        return names
    }

    private static func expenseRootCategories(from categories: [Category]) -> [Category] {
        categories
            .filter { $0.type == .expense && !$0.isHidden && $0.parent == nil }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private static func expenseChildCategories(of parent: Category) -> [Category] {
        (parent.children ?? [])
            .filter { $0.isUserSelectable && $0.type == .expense }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    static func totalSpend(
        transactions: [Transaction],
        selectedCategoryIDs: Set<UUID>,
        from start: Date,
        through end: Date,
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> Decimal {
        guard !selectedCategoryIDs.isEmpty else { return 0 }

        func inPeriod(_ transaction: Transaction) -> Bool {
            transaction.date >= start && transaction.date <= end
        }

        let splitChildTotalByParent = Dictionary(
            grouping: transactions.filter(\.isSplitChild),
            by: { $0.parentTransactionID }
        ).mapValues { children in
            children.reduce(Decimal.zero) { $0 + $1.amount }
        }

        var total: Decimal = 0

        for child in transactions where child.isSplitChild && child.type == .expense && inPeriod(child) {
            guard categoryMatchesSelection(child.category, selectedIDs: selectedCategoryIDs) else { continue }
            total += BalanceCalculator.convertedAmount(
                child.amount,
                for: child,
                baseCurrency: baseCurrency,
                exchangeRates: exchangeRates
            )
        }

        for transaction in transactions where !transaction.isSplitChild && transaction.type == .expense && inPeriod(transaction) {
            let childTotal = splitChildTotalByParent[transaction.id] ?? 0
            let remainder = transaction.amount - childTotal
            guard remainder > 0 else { continue }

            let categoryAmount: Decimal
            if categoryMatchesSelection(transaction.category, selectedIDs: selectedCategoryIDs) {
                categoryAmount = remainder
            } else {
                continue
            }

            total += BalanceCalculator.convertedAmount(
                categoryAmount,
                for: transaction,
                baseCurrency: baseCurrency,
                exchangeRates: exchangeRates
            )
        }

        return total
    }

    static func dailyAverage(
        transactions: [Transaction],
        selectedCategoryIDs: Set<UUID>,
        lookbackDays: Int,
        through end: Date = Date(),
        baseCurrency: String,
        exchangeRates: [String: Decimal],
        calendar: Calendar = .current
    ) -> Decimal {
        guard !selectedCategoryIDs.isEmpty else { return 0 }

        let endDay = calendar.startOfDay(for: end)
        guard let startDay = calendar.date(byAdding: .day, value: -(lookbackDays - 1), to: endDay) else { return 0 }

        let total = totalSpend(
            transactions: transactions,
            selectedCategoryIDs: selectedCategoryIDs,
            from: startDay,
            through: end,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )

        return total / Decimal(max(1, lookbackDays))
    }

    static func projectedVariableSpend(
        dailyAverage: Decimal,
        from startDay: Date,
        through endDay: Date,
        calendar: Calendar = .current
    ) -> Decimal {
        let start = calendar.startOfDay(for: startDay)
        let end = calendar.startOfDay(for: endDay)
        guard end > start, dailyAverage > 0 else { return 0 }

        let dayCount = (calendar.dateComponents([.day], from: start, to: end).day ?? 0)
        return dailyAverage * Decimal(dayCount)
    }
}
