import Foundation
import SwiftData

enum DebtService {
    @MainActor
    static func ensureDebtCategories(context: ModelContext) {
        ensureCategory(
            named: AppConstants.debtBorrowedCategoryName,
            icon: "arrow.down.circle.fill",
            colorHex: "#5856D6",
            type: .income,
            context: context
        )
        ensureCategory(
            named: AppConstants.debtLentCategoryName,
            icon: "arrow.up.circle.fill",
            colorHex: "#FF9500",
            type: .expense,
            context: context
        )
        ensureCategory(
            named: AppConstants.debtRepaymentCategoryName,
            icon: "arrow.up.right.circle.fill",
            colorHex: "#FF6482",
            type: .expense,
            context: context
        )
        ensureCategory(
            named: AppConstants.debtReceivedCategoryName,
            icon: "arrow.down.left.circle.fill",
            colorHex: "#34C759",
            type: .income,
            context: context
        )
    }

    @MainActor
    static func isOpeningTransaction(_ transaction: Transaction) -> Bool {
        guard let name = transaction.category?.name else { return false }
        return name == AppConstants.debtBorrowedCategoryName || name == AppConstants.debtLentCategoryName
    }

    @MainActor
    static func isRepaymentTransaction(_ transaction: Transaction) -> Bool {
        guard let name = transaction.category?.name else { return false }
        return name == AppConstants.debtRepaymentCategoryName || name == AppConstants.debtReceivedCategoryName
    }

    @MainActor
    static func isDebtLinkedTransaction(_ transaction: Transaction) -> Bool {
        isOpeningTransaction(transaction) || isRepaymentTransaction(transaction)
    }

    @MainActor
    static func openingTransaction(for debt: Debt) -> Transaction? {
        (debt.linkedTransactions ?? []).first(where: isOpeningTransaction)
    }

    @MainActor
    static func recalculateRemaining(for debt: Debt, excluding transaction: Transaction? = nil) {
        let repaid = (debt.linkedTransactions ?? [])
            .filter { $0.id != transaction?.id }
            .filter(isRepaymentTransaction)
            .reduce(Decimal.zero) { $0 + $1.amount }
        debt.remainingAmount = max(0, debt.originalAmount - repaid)
    }

    @MainActor
    @discardableResult
    static func recordOpening(
        debt: Debt,
        account: Account,
        date: Date = Date(),
        context: ModelContext
    ) -> Transaction? {
        guard debt.createsLinkedTransactions else { return nil }

        ensureDebtCategories(context: context)
        let category = openingCategory(for: debt.direction, context: context)
        let type: TransactionType = debt.direction == .iOwe ? .income : .expense
        let debtName = debt.name
        let title = debt.direction == .iOwe
            ? String(localized: "Borrowed: \(debtName)")
            : String(localized: "Lent: \(debtName)")
        let note: String
        if debt.counterparty.isEmpty {
            note = debt.note
        } else {
            let counterparty = debt.counterparty
            note = String(localized: "Counterparty: \(counterparty)")
        }

        let transaction = Transaction(
            title: title,
            amount: debt.originalAmount,
            type: type,
            date: date,
            note: note,
            account: account,
            category: category,
            transactionCurrency: account.currency == debt.currency ? nil : debt.currency
        )
        context.insert(transaction)
        link(transaction, to: debt)
        recalculateRemaining(for: debt)
        return transaction
    }

    @MainActor
    @discardableResult
    static func recordRepayment(
        debt: Debt,
        amount: Decimal,
        account: Account?,
        date: Date = Date(),
        context: ModelContext
    ) -> Transaction? {
        recalculateRemaining(for: debt)
        guard debt.remainingAmount > 0 else { return nil }

        let appliedAmount = min(amount, debt.remainingAmount)
        guard appliedAmount > 0 else { return nil }

        guard debt.createsLinkedTransactions else {
            debt.remainingAmount = max(0, debt.remainingAmount - appliedAmount)
            return nil
        }

        guard let account else { return nil }

        ensureDebtCategories(context: context)
        let category = repaymentCategory(for: debt.direction, context: context)
        let type: TransactionType = debt.direction == .iOwe ? .expense : .income
        let debtName = debt.name
        let title = debt.direction == .iOwe
            ? String(localized: "Repayment: \(debtName)")
            : String(localized: "Received: \(debtName)")
        let note: String
        if debt.counterparty.isEmpty {
            note = debt.note
        } else {
            let counterparty = debt.counterparty
            note = String(localized: "Counterparty: \(counterparty)")
        }

        let transaction = Transaction(
            title: title,
            amount: appliedAmount,
            type: type,
            date: date,
            note: note,
            account: account,
            category: category,
            transactionCurrency: account.currency == debt.currency ? nil : debt.currency
        )
        context.insert(transaction)
        link(transaction, to: debt)
        recalculateRemaining(for: debt)
        return transaction
    }

    static func debtsDue(on day: Date, debts: [Debt], calendar: Calendar = .current) -> [Debt] {
        let dayStart = calendar.startOfDay(for: day)
        return debts.filter { debt in
            guard debt.remainingAmount > 0, let dueDate = debt.dueDate else { return false }
            return calendar.startOfDay(for: dueDate) == dayStart
        }
    }

    static func totalDebtNetWorthImpact(
        from start: Date,
        through end: Date,
        debts: [Debt],
        baseCurrency: String,
        exchangeRates: [String: Decimal],
        calendar: Calendar = .current
    ) -> Decimal {
        let rangeStart = calendar.startOfDay(for: start)
        let rangeEnd = calendar.startOfDay(for: end)
        guard rangeEnd >= rangeStart else { return 0 }

        var total: Decimal = 0
        for debt in debts {
            guard debt.remainingAmount > 0, let dueDate = debt.dueDate else { continue }
            let dueDay = calendar.startOfDay(for: dueDate)
            guard dueDay >= rangeStart, dueDay <= rangeEnd else { continue }

            let converted = BalanceCalculator.convert(
                debt.remainingAmount,
                from: debt.currency,
                to: baseCurrency,
                rates: exchangeRates
            )
            switch debt.direction {
            case .iOwe:
                total += converted
            case .theyOwe:
                total -= converted
            }
        }
        return total
    }

    @MainActor
    static func handleLinkedTransactionDeletion(_ transaction: Transaction, context: ModelContext) {
        guard let debts = transaction.linkedDebts, !debts.isEmpty else { return }
        for debt in debts {
            recalculateRemaining(for: debt, excluding: transaction)
        }
    }

    @MainActor
    static func syncOpeningTransaction(for debt: Debt, context: ModelContext) {
        guard debt.createsLinkedTransactions, let opening = openingTransaction(for: debt) else { return }
        opening.amount = debt.originalAmount
        opening.date = debt.createdAt
        let debtName = debt.name
        opening.title = debt.direction == .iOwe
            ? String(localized: "Borrowed: \(debtName)")
            : String(localized: "Lent: \(debtName)")
        if debt.counterparty.isEmpty {
            opening.note = debt.note
        } else {
            let counterparty = debt.counterparty
            opening.note = String(localized: "Counterparty: \(counterparty)")
        }
        opening.transactionCurrency = opening.account?.currency == debt.currency ? nil : debt.currency
        recalculateRemaining(for: debt)
    }

    @MainActor
    static func deleteDebt(_ debt: Debt, context: ModelContext) {
        NotificationService.shared.cancelDebtReminder(debt: debt)
        for transaction in debt.linkedTransactions ?? [] {
            context.delete(transaction)
        }
        context.delete(debt)
    }

    @MainActor
    private static func openingCategory(for direction: DebtDirection, context: ModelContext) -> Category {
        let name = direction == .iOwe
            ? AppConstants.debtBorrowedCategoryName
            : AppConstants.debtLentCategoryName
        return category(named: name, context: context) {
            Category(
                name: name,
                icon: direction == .iOwe ? "arrow.down.circle.fill" : "arrow.up.circle.fill",
                colorHex: direction == .iOwe ? "#5856D6" : "#FF9500",
                type: direction == .iOwe ? .income : .expense,
                isSystem: true,
                isHidden: true,
                isDebtOnly: true
            )
        }
    }

    @MainActor
    private static func repaymentCategory(for direction: DebtDirection, context: ModelContext) -> Category {
        let name = direction == .iOwe
            ? AppConstants.debtRepaymentCategoryName
            : AppConstants.debtReceivedCategoryName
        return category(named: name, context: context) {
            Category(
                name: name,
                icon: direction == .iOwe ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill",
                colorHex: direction == .iOwe ? "#FF6482" : "#34C759",
                type: direction == .iOwe ? .expense : .income,
                isSystem: true,
                isHidden: true,
                isDebtOnly: true
            )
        }
    }

    @MainActor
    private static func category(named name: String, context: ModelContext, fallback: () -> Category) -> Category {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.name == name })
        if let category = try? context.fetch(descriptor).first {
            return category
        }
        let category = fallback()
        context.insert(category)
        return category
    }

    @MainActor
    private static func link(_ transaction: Transaction, to debt: Debt) {
        if debt.linkedTransactions == nil {
            debt.linkedTransactions = [transaction]
        } else if debt.linkedTransactions?.contains(where: { $0.id == transaction.id }) != true {
            debt.linkedTransactions?.append(transaction)
        }
    }

    @MainActor
    private static func ensureCategory(
        named name: String,
        icon: String,
        colorHex: String,
        type: CategoryType,
        context: ModelContext
    ) {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.name == name })
        if let existing = try? context.fetch(descriptor).first {
            existing.icon = icon
            existing.colorHex = colorHex
            existing.typeRaw = type.rawValue
            existing.isSystem = true
            existing.isHidden = true
            existing.isDebtOnly = true
            return
        }

        let category = Category(
            name: name,
            icon: icon,
            colorHex: colorHex,
            type: type,
            isSystem: true,
            isHidden: true,
            isDebtOnly: true
        )
        context.insert(category)
    }
}
