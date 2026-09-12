import Foundation
import SwiftData

enum BalanceCalculator {
    /// One pass over transactions for every account balance (avoids N full scans on dashboard).
    static func balancesByAccountID(accounts: [Account], transactions: [Transaction]) -> [UUID: Decimal] {
        var balances: [UUID: Decimal] = [:]
        balances.reserveCapacity(accounts.count)
        for account in accounts {
            balances[account.id] = account.initialBalance
        }

        for transaction in transactions where !transaction.isSplitChild {
            switch transaction.type {
            case .income:
                if let id = transaction.account?.id {
                    balances[id, default: 0] += transaction.amount
                }
            case .expense:
                if let id = transaction.account?.id {
                    balances[id, default: 0] -= transaction.amount
                }
            case .transfer:
                if let id = transaction.account?.id {
                    balances[id, default: 0] -= transaction.amount
                }
                if let id = transaction.toAccount?.id {
                    balances[id, default: 0] += transaction.amount
                }
            }
        }
        return balances
    }

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

    static func netWorth(
        accounts: [Account],
        transactions: [Transaction],
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> Decimal {
        netWorth(
            accounts: accounts,
            balances: balancesByAccountID(accounts: accounts, transactions: transactions),
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )
    }

    static func netWorth(
        accounts: [Account],
        balances: [UUID: Decimal],
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> Decimal {
        accounts
            .filter { $0.includeInTotal && !$0.isHidden }
            .reduce(Decimal.zero) { partial, account in
                let balance = balances[account.id] ?? account.initialBalance
                return partial + convert(balance, from: account.currency, to: baseCurrency, rates: exchangeRates)
            }
    }

    /// Net worth at each sample by reversing txs after that date from current balances.
    /// `laterTransactions` must include every non-split tx with `date > earliestSample`.
    static func netWorthHistory(
        sampleDates: [Date],
        accounts: [Account],
        currentBalances: [UUID: Decimal],
        laterTransactions: [Transaction],
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> [(date: Date, value: Decimal)] {
        let samples = sampleDates.sorted(by: >)
        guard !samples.isEmpty else { return [] }

        var balances = currentBalances
        let txs = laterTransactions
            .filter { !$0.isSplitChild }
            .sorted { $0.date > $1.date }
        var txIndex = 0
        var points: [(Date, Decimal)] = []
        points.reserveCapacity(samples.count)

        for sample in samples {
            while txIndex < txs.count, txs[txIndex].date > sample {
                apply(txs[txIndex], to: &balances, reversing: true)
                txIndex += 1
            }
            points.append((
                sample,
                netWorth(accounts: accounts, balances: balances, baseCurrency: baseCurrency, exchangeRates: exchangeRates)
            ))
        }

        return points.reversed()
    }

    static func apply(_ transaction: Transaction, to balances: inout [UUID: Decimal], reversing: Bool = false) {
        guard !transaction.isSplitChild else { return }
        let sign: Decimal = reversing ? -1 : 1
        switch transaction.type {
        case .income:
            if let id = transaction.account?.id {
                balances[id, default: 0] += transaction.amount * sign
            }
        case .expense:
            if let id = transaction.account?.id {
                balances[id, default: 0] -= transaction.amount * sign
            }
        case .transfer:
            if let id = transaction.account?.id {
                balances[id, default: 0] -= transaction.amount * sign
            }
            if let id = transaction.toAccount?.id {
                balances[id, default: 0] += transaction.amount * sign
            }
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

    static func dayNetCashFlow(
        transactions: [Transaction],
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> Decimal {
        transactions.reduce(Decimal.zero) { partial, item in
            let converted = convertedAmount(
                item.amount,
                for: item,
                baseCurrency: baseCurrency,
                exchangeRates: exchangeRates
            )
            switch item.type {
            case .income: return partial + converted
            case .expense: return partial - converted
            case .transfer: return partial
            }
        }
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
