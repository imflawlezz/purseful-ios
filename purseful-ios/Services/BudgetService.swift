import Foundation
import SwiftData

enum BudgetService {
    struct PeriodRange {
        let start: Date
        let end: Date
    }

    static func periodRange(for budget: Budget, referenceDate: Date = Date()) -> PeriodRange {
        let calendar = Calendar.current
        switch budget.period {
        case .weekly:
            let start = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? referenceDate
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? referenceDate
            return PeriodRange(start: start, end: end)
        case .monthly:
            let start = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? referenceDate
            return PeriodRange(start: start, end: end)
        case .custom:
            let start = budget.customStartDate ?? referenceDate
            let end = budget.customEndDate ?? referenceDate
            return PeriodRange(start: start, end: end)
        }
    }

    static func spentAmount(
        budget: Budget,
        transactions: [Transaction],
        period: PeriodRange? = nil,
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> Decimal {
        let range = period ?? periodRange(for: budget)
        let calendar = Calendar.current
        let periodStart = calendar.startOfDay(for: range.start)
        let periodEnd = calendar.startOfDay(for: range.end)

        let inPeriod: (Transaction) -> Bool = { transaction in
            let day = calendar.startOfDay(for: transaction.date)
            return day >= periodStart && day < periodEnd
        }

        func countsTowardBudget(amount: Decimal, category: Category?, title: String) -> Decimal {
            guard amount > 0 else { return 0 }
            guard let budgetCategory = budget.category else { return amount }
            if categoriesMatch(category, budgetCategory: budgetCategory) { return amount }
            if title.localizedCaseInsensitiveCompare(budgetCategory.name) == .orderedSame { return amount }
            if title.localizedCaseInsensitiveCompare(budget.name) == .orderedSame { return amount }
            return 0
        }

        let splitChildren = transactions.filter(\.isSplitChild)
        let splitChildTotalByParent = Dictionary(
            grouping: splitChildren,
            by: { $0.parentTransactionID }
        ).mapValues { children in
            children.reduce(Decimal.zero) { $0 + $1.amount }
        }

        var total: Decimal = 0

        for child in splitChildren where child.type == .expense && inPeriod(child) {
            let converted = BalanceCalculator.convertedAmount(
                child.amount,
                for: child,
                baseCurrency: baseCurrency,
                exchangeRates: exchangeRates
            )
            total += countsTowardBudget(amount: converted, category: child.category, title: child.title)
        }

        for transaction in transactions where !transaction.isSplitChild && transaction.type == .expense && inPeriod(transaction) {
            let childTotal = splitChildTotalByParent[transaction.id] ?? 0
            let remainder = transaction.amount - childTotal
            let converted = BalanceCalculator.convertedAmount(
                remainder,
                for: transaction,
                baseCurrency: baseCurrency,
                exchangeRates: exchangeRates
            )
            total += countsTowardBudget(amount: converted, category: transaction.category, title: transaction.title)
        }

        return total
    }

    static func effectiveLimit(budget: Budget) -> Decimal {
        budget.amount + (budget.rollover ? budget.rolloverAmount : 0)
    }

    static func processRollovers(
        budgets: [Budget],
        transactions: [Transaction],
        baseCurrency: String,
        exchangeRates: [String: Decimal],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        var didChange = false

        for budget in budgets {
            guard budget.period != .custom else { continue }

            let currentRange = periodRange(for: budget, referenceDate: referenceDate)
            let currentStart = calendar.startOfDay(for: currentRange.start)

            guard let trackedStart = budget.rolloverPeriodStart.map({ calendar.startOfDay(for: $0) }) else {
                budget.rolloverPeriodStart = currentStart
                didChange = true
                continue
            }

            guard trackedStart < currentStart else { continue }

            var periodStart = trackedStart
            while periodStart < currentStart {
                let range = periodRange(for: budget, referenceDate: periodStart)
                let spent = spentAmount(
                    budget: budget,
                    transactions: transactions,
                    period: range,
                    baseCurrency: baseCurrency,
                    exchangeRates: exchangeRates
                )
                let limit = effectiveLimit(budget: budget)

                if budget.rollover {
                    budget.rolloverAmount = max(0, limit - spent)
                } else {
                    budget.rolloverAmount = 0
                }

                periodStart = calendar.startOfDay(for: range.end)
            }

            budget.rolloverPeriodStart = currentStart
            didChange = true
        }

        return didChange
    }

    static func progress(spent: Decimal, limit: Decimal) -> Double {
        guard limit > 0 else { return 0 }
        return min(1.2, NSDecimalNumber(decimal: spent / limit).doubleValue)
    }

    static func progressColor(progress: Double, threshold: Double) -> String {
        if progress >= 1 { return "#FF3B30" }
        if progress >= threshold { return "#FF9500" }
        return "#34C759"
    }

    /// Budget category, ancestor, or descendant.
    static func categoriesMatch(_ transactionCategory: Category?, budgetCategory: Category) -> Bool {
        guard let transactionCategory else { return false }

        if transactionCategory.id == budgetCategory.id { return true }

        var ancestor = transactionCategory.parent
        while let current = ancestor {
            if current.id == budgetCategory.id { return true }
            ancestor = current.parent
        }

        return isDescendant(of: budgetCategory, category: transactionCategory)
    }

    private static func isDescendant(of ancestor: Category, category: Category) -> Bool {
        for child in ancestor.children ?? [] {
            if child.id == category.id { return true }
            if isDescendant(of: child, category: category) { return true }
        }
        return false
    }

    static func matchingTransactions(
        for budget: Budget,
        transactions: [Transaction],
        period: PeriodRange? = nil
    ) -> [Transaction] {
        let range = period ?? periodRange(for: budget)
        let calendar = Calendar.current
        let periodStart = calendar.startOfDay(for: range.start)
        let periodEnd = calendar.startOfDay(for: range.end)

        func inPeriod(_ transaction: Transaction) -> Bool {
            let day = calendar.startOfDay(for: transaction.date)
            return day >= periodStart && day < periodEnd
        }

        func matchesBudget(_ transaction: Transaction) -> Bool {
            guard transaction.type == .expense else { return false }
            guard let budgetCategory = budget.category else { return true }
            if categoriesMatch(transaction.category, budgetCategory: budgetCategory) { return true }
            if transaction.title.localizedCaseInsensitiveCompare(budgetCategory.name) == .orderedSame { return true }
            if transaction.title.localizedCaseInsensitiveCompare(budget.name) == .orderedSame { return true }
            return false
        }

        return transactions
            .filter { inPeriod($0) && matchesBudget($0) }
            .sorted { $0.date > $1.date }
    }

    static func monthlyHistory(
        for budget: Budget,
        transactions: [Transaction],
        baseCurrency: String,
        exchangeRates: [String: Decimal],
        monthCount: Int = 3,
        calendar: Calendar = .current
    ) -> [(label: String, spent: Decimal)] {
        (0..<monthCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: Date()) else { return nil }
            let range = periodRange(for: budget, referenceDate: date)
            let spent = spentAmount(
                budget: budget,
                transactions: transactions,
                period: range,
                baseCurrency: baseCurrency,
                exchangeRates: exchangeRates
            )
            return (DateFormatters.monthYearString(from: range.start), spent)
        }
    }
}
