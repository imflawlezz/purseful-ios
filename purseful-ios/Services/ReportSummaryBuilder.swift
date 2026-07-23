import Foundation

struct ReportCategoryRow: Sendable {
    let name: String
    let amount: Decimal
    let sharePercent: Double
}

struct ReportSummary: Sendable {
    let periodLabel: String
    let generatedAt: Date
    let baseCurrency: String
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let netCashFlow: Decimal
    let transactionCount: Int
    let spendingTrendLabel: String
    let categories: [ReportCategoryRow]
}

struct ReportPDFLine: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let dateTimeLabel: String
    let title: String
    let accountLabel: String
    let categoryName: String
    let amountLabel: String
}

enum ReportSummaryBuilder {
    static func build(
        transactions: [Transaction],
        from start: Date,
        through end: Date,
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> (summary: ReportSummary, lines: [ReportPDFLine]) {
        let periodLabel = "\(DateFormatters.reportPDFRangeString(from: start)) – \(DateFormatters.reportPDFRangeString(from: end))"
        let income = BalanceCalculator.totalIncome(
            transactions: transactions,
            from: start,
            through: end,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )
        let expenses = BalanceCalculator.totalExpenses(
            transactions: transactions,
            from: start,
            through: end,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )
        let categoryRows = BalanceCalculator.categorySpending(
            transactions: transactions,
            from: start,
            through: end,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )
        .map { name, amount in
            let sharePercent: Double
            if expenses > 0 {
                let ratio = (amount as NSDecimalNumber).dividing(by: expenses as NSDecimalNumber)
                sharePercent = ratio.multiplying(by: 100).doubleValue
            } else {
                sharePercent = 0
            }
            return ReportCategoryRow(name: name, amount: amount, sharePercent: sharePercent)
        }
        .sorted { $0.amount > $1.amount }

        let parentsInPeriod = transactions.filter {
            !$0.isSplitChild && $0.date >= start && $0.date <= end
        }

        let lines = ledgerLines(
            transactions: transactions,
            parentsInPeriod: parentsInPeriod,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )

        let summary = ReportSummary(
            periodLabel: periodLabel,
            generatedAt: Date(),
            baseCurrency: baseCurrency,
            totalIncome: income,
            totalExpenses: expenses,
            netCashFlow: income - expenses,
            transactionCount: lines.count,
            spendingTrendLabel: spendingTrendLabel(
                transactions: transactions,
                periodStart: start,
                periodEnd: end,
                baseCurrency: baseCurrency,
                exchangeRates: exchangeRates
            ),
            categories: categoryRows
        )

        return (summary, lines)
    }

    private static func ledgerLines(
        transactions: [Transaction],
        parentsInPeriod: [Transaction],
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> [ReportPDFLine] {
        var childrenByParent: [UUID: [Transaction]] = [:]
        for child in transactions where child.isSplitChild {
            guard let parentID = child.parentTransactionID else { continue }
            childrenByParent[parentID, default: []].append(child)
        }

        var lines: [ReportPDFLine] = []
        for parent in parentsInPeriod {
            let children = childrenByParent[parent.id] ?? []
            if children.isEmpty {
                lines.append(
                    makeLine(
                        parent: parent,
                        amountSource: parent,
                        amount: parent.amount,
                        baseCurrency: baseCurrency,
                        exchangeRates: exchangeRates
                    )
                )
                continue
            }

            for child in children {
                lines.append(
                    makeLine(
                        parent: parent,
                        amountSource: child,
                        amount: child.amount,
                        baseCurrency: baseCurrency,
                        exchangeRates: exchangeRates
                    )
                )
            }

            let childTotal = children.reduce(Decimal.zero) { $0 + $1.amount }
            let remainder = parent.amount - childTotal
            if remainder > 0 {
                lines.append(
                    makeLine(
                        parent: parent,
                        amountSource: parent,
                        amount: remainder,
                        baseCurrency: baseCurrency,
                        exchangeRates: exchangeRates
                    )
                )
            }
        }

        return lines.sorted { $0.date < $1.date }
    }

    private static func makeLine(
        parent: Transaction,
        amountSource: Transaction,
        amount: Decimal,
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> ReportPDFLine {
        let converted = BalanceCalculator.convertedAmount(
            amount,
            for: amountSource,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )
        let amountLabel = formattedAmount(
            converted,
            type: amountSource.type,
            currencyCode: baseCurrency
        )

        return ReportPDFLine(
            id: amountSource.id,
            date: parent.date,
            dateTimeLabel: DateFormatters.reportPDFDateTime.string(from: parent.date),
            title: displayTitle(parent: parent, amountSource: amountSource),
            accountLabel: accountLabel(for: parent),
            categoryName: amountSource.category?.name ?? categoryFallback(for: amountSource.type),
            amountLabel: amountLabel
        )
    }

    private static func displayTitle(parent: Transaction, amountSource: Transaction) -> String {
        if !parent.title.isEmpty { return parent.title }
        if parent.id != amountSource.id, !amountSource.title.isEmpty { return amountSource.title }
        return amountSource.category?.name ?? "Transaction"
    }

    private static func accountLabel(for transaction: Transaction) -> String {
        switch transaction.type {
        case .transfer:
            let from = transaction.account?.name ?? "—"
            let to = transaction.toAccount?.name ?? "—"
            return "\(from) → \(to)"
        default:
            return transaction.account?.name ?? "—"
        }
    }

    private static func categoryFallback(for type: TransactionType) -> String {
        switch type {
        case .income: AppConstants.otherIncomeCategoryName
        case .expense: AppConstants.otherExpenseCategoryName
        case .transfer: "Transfer"
        }
    }

    private static func formattedAmount(
        _ amount: Decimal,
        type: TransactionType,
        currencyCode: String
    ) -> String {
        let prefix: String
        switch type {
        case .income: prefix = "+"
        case .expense: prefix = "-"
        case .transfer: prefix = ""
        }
        return prefix + CurrencyFormatter.format(amount, currencyCode: currencyCode)
    }

    private static func spendingTrendLabel(
        transactions: [Transaction],
        periodStart: Date,
        periodEnd: Date,
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: periodStart)
        let end = periodEnd
        let dayCount = max(
            1,
            (calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: end)).day ?? 0) + 1
        )

        guard let previousEnd = calendar.date(byAdding: .day, value: -1, to: start),
              let previousStart = calendar.date(byAdding: .day, value: -(dayCount - 1), to: previousEnd) else {
            return "vs previous period: —"
        }

        let current = BalanceCalculator.totalExpenses(
            transactions: transactions,
            from: start,
            through: end,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )
        let previous = BalanceCalculator.totalExpenses(
            transactions: transactions,
            from: previousStart,
            through: previousEnd,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )
        let delta = current - previous

        guard previous > 0 else {
            if current > 0 {
                return "vs previous period: no prior spending"
            }
            return "vs previous period: 0%"
        }

        let percent = (delta / previous) * 100
        let value = NSDecimalNumber(decimal: percent).doubleValue
        return String(format: "vs previous period: %+.0f%%", value)
    }
}
