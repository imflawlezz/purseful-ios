import Foundation
import SwiftData

enum BalanceCalculator {
    static func currentBalance(for account: Account, transactions: [Transaction]) -> Decimal {
        account.initialBalance + transactionNetEffect(for: account, transactions: transactions)
    }

    static func transactionNetEffect(for account: Account, transactions: [Transaction]) -> Decimal {
        var effect = Decimal.zero
        let accountID = account.id

        for transaction in transactions where !transaction.isSplitChild {
            switch transaction.type {
            case .income:
                if transaction.account?.id == accountID {
                    effect += transaction.amount
                }
            case .expense:
                if transaction.account?.id == accountID {
                    effect -= transaction.amount
                }
            case .transfer:
                if transaction.account?.id == accountID {
                    effect -= transaction.amount
                }
                if transaction.toAccount?.id == accountID {
                    effect += transaction.amount
                }
            }
        }
        return effect
    }

    static func netWorth(accounts: [Account], transactions: [Transaction], baseCurrency: String, exchangeRates: [String: Decimal]) -> Decimal {
        accounts
            .filter { $0.includeInTotal && !$0.isHidden }
            .reduce(Decimal.zero) { partial, account in
                let balance = currentBalance(for: account, transactions: transactions)
                return partial + convert(balance, from: account.currency, to: baseCurrency, rates: exchangeRates)
            }
    }

    /// Rates are stored as units of each currency per 1 unit of the base currency (Frankfurter `from=base` format).
    static func convert(_ amount: Decimal, from: String, to: String, rates: [String: Decimal]) -> Decimal {
        if from == to { return amount }
        guard let fromRate = rates[from], let toRate = rates[to], fromRate != 0 else {
            return amount
        }
        return amount * toRate / fromRate
    }

    static func currency(for transaction: Transaction, baseCurrency: String) -> String {
        transaction.transactionCurrency ?? transaction.account?.currency ?? baseCurrency
    }

    static func convertedAmount(
        _ amount: Decimal,
        for transaction: Transaction,
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> Decimal {
        let fromCurrency = currency(for: transaction, baseCurrency: baseCurrency)
        if fromCurrency == baseCurrency { return amount }

        if let storedRate = transaction.exchangeRate,
           storedRate > 0,
           transaction.transactionCurrency != nil {
            return amount * storedRate
        }

        return convert(amount, from: fromCurrency, to: baseCurrency, rates: exchangeRates)
    }

    static func convertedPlannedPaymentAmount(
        _ payment: PlannedPayment,
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> Decimal {
        let currency = payment.account?.currency ?? baseCurrency
        return convert(payment.amount, from: currency, to: baseCurrency, rates: exchangeRates)
    }

    static func cashFlow(
        transactions: [Transaction],
        from start: Date,
        to end: Date,
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> (income: Decimal, expense: Decimal) {
        var income: Decimal = 0
        var expense: Decimal = 0

        for transaction in transactions where !transaction.isSplitChild {
            guard transaction.date >= start && transaction.date <= end else { continue }
            let converted = convertedAmount(transaction.amount, for: transaction, baseCurrency: baseCurrency, exchangeRates: exchangeRates)

            switch transaction.type {
            case .income:
                income += converted
            case .expense:
                expense += converted
            case .transfer:
                break
            }
        }
        return (income, expense)
    }

    static func totalExpenses(
        transactions: [Transaction],
        from start: Date,
        through end: Date,
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> Decimal {
        transactions
            .filter { !$0.isSplitChild && $0.type == .expense && $0.date >= start && $0.date <= end }
            .reduce(Decimal.zero) {
                $0 + convertedAmount($1.amount, for: $1, baseCurrency: baseCurrency, exchangeRates: exchangeRates)
            }
    }

    static func totalIncome(
        transactions: [Transaction],
        from start: Date,
        through end: Date,
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> Decimal {
        transactions
            .filter { !$0.isSplitChild && $0.type == .income && $0.date >= start && $0.date <= end }
            .reduce(Decimal.zero) {
                $0 + convertedAmount($1.amount, for: $1, baseCurrency: baseCurrency, exchangeRates: exchangeRates)
            }
    }

    /// Split-aware category totals in the base currency.
    static func categorySpending(
        transactions: [Transaction],
        from start: Date,
        through end: Date,
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> [String: Decimal] {
        func inPeriod(_ transaction: Transaction) -> Bool {
            transaction.date >= start && transaction.date <= end
        }

        let splitChildTotalByParent = Dictionary(
            grouping: transactions.filter(\.isSplitChild),
            by: { $0.parentTransactionID }
        ).mapValues { children in
            children.reduce(Decimal.zero) { $0 + $1.amount }
        }

        var totals: [String: Decimal] = [:]

        func add(_ amount: Decimal, categoryName: String) {
            guard amount > 0 else { return }
            totals[categoryName, default: 0] += amount
        }

        for child in transactions where child.isSplitChild && child.type == .expense && inPeriod(child) {
            let converted = convertedAmount(child.amount, for: child, baseCurrency: baseCurrency, exchangeRates: exchangeRates)
            add(converted, categoryName: child.category?.name ?? AppConstants.otherExpenseCategoryName)
        }

        for transaction in transactions where !transaction.isSplitChild && transaction.type == .expense && inPeriod(transaction) {
            let childTotal = splitChildTotalByParent[transaction.id] ?? 0
            let remainder = transaction.amount - childTotal
            guard remainder > 0 else { continue }
            let converted = convertedAmount(remainder, for: transaction, baseCurrency: baseCurrency, exchangeRates: exchangeRates)
            add(converted, categoryName: transaction.category?.name ?? AppConstants.otherExpenseCategoryName)
        }

        return totals
    }
}
