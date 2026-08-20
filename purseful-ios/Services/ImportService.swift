import Foundation
import SwiftData

enum ImportService {
    struct ImportResult {
        let accounts: Int
        let categories: Int
        let transactions: Int
        let budgets: Int
        let goals: Int
        let plannedPayments: Int
        let debts: Int
        let recurringRules: Int
        let shoppingList: Int
        let skippedDuplicates: Int
    }

    static func isAppExport(_ data: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(ExportPayload.self, from: data) else { return false }
        return payload.formatVersion >= 1
    }

    @MainActor
    static func importJSON(data: Data, context: ModelContext, merge: Bool) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportPayload.self, from: data)

        if !merge {
            try PursefulWebImportService.replaceAllData(context: context)
        }

        var accountByID: [UUID: Account] = [:]
        var categoryByID: [UUID: Category] = [:]
        var ruleByID: [UUID: RecurringRule] = [:]
        var transactionByID: [UUID: Transaction] = [:]
        var skippedDuplicates = 0

        let existingAccounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let existingCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let existingImportIDs = merge
            ? Set(((try? context.fetch(FetchDescriptor<Transaction>())) ?? []).compactMap(\.importSourceID))
            : []
        let existingTransactionIDs = merge
            ? Set(((try? context.fetch(FetchDescriptor<Transaction>())) ?? []).map(\.id))
            : []

        for exportAccount in payload.accounts {
            let account: Account
            if merge, let existing = existingAccounts.first(where: { $0.id == exportAccount.id }) {
                account = existing
            } else {
                account = Account(
                    name: exportAccount.name,
                    type: AccountType(rawValue: exportAccount.type) ?? .cash,
                    currency: exportAccount.currency,
                    initialBalance: Decimal(string: exportAccount.initialBalance) ?? 0,
                    colorHex: exportAccount.colorHex ?? "#007AFF",
                    icon: exportAccount.icon ?? "banknote",
                    includeInTotal: exportAccount.includeInTotal ?? true
                )
                account.id = exportAccount.id
                account.sortOrder = exportAccount.sortOrder ?? AccountPreferences.nextSortOrder(accounts: existingAccounts)
                context.insert(account)
            }

            account.name = exportAccount.name
            account.type = AccountType(rawValue: exportAccount.type) ?? account.type
            account.currency = exportAccount.currency
            account.initialBalance = Decimal(string: exportAccount.initialBalance) ?? account.initialBalance
            if let colorHex = exportAccount.colorHex { account.colorHex = colorHex }
            if let icon = exportAccount.icon { account.icon = icon }
            if let includeInTotal = exportAccount.includeInTotal { account.includeInTotal = includeInTotal }
            if let sortOrder = exportAccount.sortOrder { account.sortOrder = sortOrder }
            if let isHidden = exportAccount.isHidden { account.isHidden = isHidden }

            accountByID[exportAccount.id] = account
        }

        var categoryByName: [String: Category] = [:]
        for category in existingCategories + Array(categoryByID.values) {
            categoryByName[category.name] = category
        }

        let sortedCategories = payload.categories.sorted {
            ($0.parentName ?? "").localizedCaseInsensitiveCompare($1.parentName ?? "") == .orderedAscending
        }

        for exportCategory in sortedCategories {
            let category: Category
            if merge, let existing = existingCategories.first(where: { $0.id == exportCategory.id }) {
                category = existing
            } else {
                category = Category(
                    name: exportCategory.name,
                    icon: exportCategory.icon,
                    colorHex: exportCategory.colorHex ?? "#8E8E93",
                    type: CategoryType(rawValue: exportCategory.type) ?? .expense,
                    isSystem: exportCategory.isSystem ?? false
                )
                category.id = exportCategory.id
                context.insert(category)
            }

            category.name = exportCategory.name
            category.icon = exportCategory.icon
            category.colorHex = exportCategory.colorHex ?? category.colorHex
            category.type = CategoryType(rawValue: exportCategory.type) ?? category.type
            if let isSystem = exportCategory.isSystem { category.isSystem = isSystem }
            if let sortOrder = exportCategory.sortOrder { category.sortOrder = sortOrder }

            if let parentName = exportCategory.parentName,
               let parent = categoryByName[parentName] ?? categoryByID.values.first(where: { $0.name == parentName }) {
                category.parent = parent
            }

            categoryByID[exportCategory.id] = category
            categoryByName[category.name] = category
        }

        for exportRule in payload.recurringRules {
            if merge, (try? context.fetch(FetchDescriptor<RecurringRule>()))?.contains(where: { $0.id == exportRule.id }) == true {
                continue
            }

            let rule = RecurringRule(
                frequency: PaymentFrequency(rawValue: exportRule.frequency) ?? .monthly,
                interval: exportRule.interval,
                startDate: exportRule.startDate,
                endDate: exportRule.endDate,
                daysOfWeek: exportRule.daysOfWeek
            )
            rule.id = exportRule.id
            context.insert(rule)
            ruleByID[exportRule.id] = rule
        }

        var importedBudgets = 0
        for exportBudget in payload.budgets {
            if merge, (try? context.fetch(FetchDescriptor<Budget>()))?.contains(where: { $0.id == exportBudget.id }) == true {
                continue
            }

            let budget = Budget(
                name: exportBudget.name,
                amount: Decimal(string: exportBudget.amount) ?? 0,
                period: BudgetPeriod(rawValue: exportBudget.period) ?? .monthly,
                category: exportBudget.categoryName.flatMap { categoryByName[$0] },
                rollover: exportBudget.rollover ?? false,
                alertThreshold: exportBudget.alertThreshold ?? 0.8,
                customStartDate: exportBudget.customStartDate,
                customEndDate: exportBudget.customEndDate
            )
            budget.id = exportBudget.id
            if let rolloverAmount = exportBudget.rolloverAmount {
                budget.rolloverAmount = Decimal(string: rolloverAmount) ?? 0
            }
            budget.rolloverPeriodStart = exportBudget.rolloverPeriodStart
            context.insert(budget)
            importedBudgets += 1
        }

        var importedGoals = 0
        for exportGoal in payload.goals {
            if merge, (try? context.fetch(FetchDescriptor<Goal>()))?.contains(where: { $0.id == exportGoal.id }) == true {
                continue
            }

            let goal = Goal(
                name: exportGoal.name,
                targetAmount: Decimal(string: exportGoal.targetAmount) ?? 0,
                icon: exportGoal.icon ?? "star.fill",
                colorHex: exportGoal.colorHex ?? "#34C759",
                currentAmount: Decimal(string: exportGoal.currentAmount) ?? 0,
                targetDate: exportGoal.targetDate,
                linkedAccount: exportGoal.linkedAccountName.flatMap { name in
                    accountByID.values.first { $0.name == name }
                        ?? existingAccounts.first { $0.name == name }
                },
                note: exportGoal.note ?? ""
            )
            goal.id = exportGoal.id
            goal.isCompleted = exportGoal.isCompleted ?? false
            context.insert(goal)
            importedGoals += 1
        }

        var importedPayments = 0
        for exportPayment in payload.plannedPayments {
            if merge, (try? context.fetch(FetchDescriptor<PlannedPayment>()))?.contains(where: { $0.id == exportPayment.id }) == true {
                continue
            }

            guard let accountName = exportPayment.accountName,
                  let account = accountByID.values.first(where: { $0.name == accountName })
                    ?? existingAccounts.first(where: { $0.name == accountName }) else {
                continue
            }

            let payment = PlannedPayment(
                name: exportPayment.name,
                amount: Decimal(string: exportPayment.amount) ?? 0,
                category: exportPayment.categoryName.flatMap { categoryByName[$0] },
                account: account,
                frequency: PaymentFrequency(rawValue: exportPayment.frequency) ?? .monthly,
                type: TransactionType(rawValue: exportPayment.type) ?? .expense,
                nextDueDate: exportPayment.nextDueDate,
                isActive: exportPayment.isActive,
                autoCategorize: exportPayment.autoCategorize,
                reminderDaysBefore: exportPayment.reminderDaysBefore
            )
            payment.id = exportPayment.id
            payment.note = exportPayment.note ?? ""
            payment.lastPaidDate = exportPayment.lastPaidDate
            payment.toAccount = exportPayment.toAccountName.flatMap { name in
                accountByID.values.first { $0.name == name }
                    ?? existingAccounts.first(where: { $0.name == name })
            }
            if let ruleID = exportPayment.recurringRuleID {
                payment.recurringRule = ruleByID[ruleID]
            }
            context.insert(payment)
            importedPayments += 1
        }

        var debtByID: [UUID: Debt] = [:]
        var importedDebts = 0
        for exportDebt in payload.debts {
            if merge, (try? context.fetch(FetchDescriptor<Debt>()))?.contains(where: { $0.id == exportDebt.id }) == true {
                continue
            }

            let debt = Debt(
                name: exportDebt.name,
                counterparty: exportDebt.counterparty,
                direction: DebtDirection(rawValue: exportDebt.direction) ?? .iOwe,
                originalAmount: Decimal(string: exportDebt.originalAmount) ?? 0,
                currency: exportDebt.currency,
                dueDate: exportDebt.dueDate,
                note: exportDebt.note ?? "",
                createdAt: exportDebt.createdAt,
                createsLinkedTransactions: exportDebt.createsLinkedTransactions
            )
            debt.id = exportDebt.id
            debt.remainingAmount = Decimal(string: exportDebt.remainingAmount) ?? debt.originalAmount
            context.insert(debt)
            debtByID[exportDebt.id] = debt
            importedDebts += 1
        }

        let sortedTransactions = payload.transactions.sorted { $0.date < $1.date }
        var importedTransactions = 0

        for exportTransaction in sortedTransactions {
            if merge {
                if existingTransactionIDs.contains(exportTransaction.id) {
                    skippedDuplicates += 1
                    continue
                }
                if let sourceID = exportTransaction.importSourceID, existingImportIDs.contains(sourceID) {
                    skippedDuplicates += 1
                    continue
                }
            }

            guard let accountName = exportTransaction.accountName,
                  let account = accountByID.values.first(where: { $0.name == accountName })
                    ?? existingAccounts.first(where: { $0.name == accountName }) else {
                continue
            }

            let category = exportTransaction.categoryName.flatMap { categoryByName[$0] }
            let toAccount = exportTransaction.toAccountName.flatMap { name in
                accountByID.values.first { $0.name == name }
                    ?? existingAccounts.first(where: { $0.name == name })
            }

            let txType = TransactionType(rawValue: exportTransaction.type) ?? .expense
            let resolvedCategory = CategoryService.resolvedCategory(category, for: txType, context: context)

            let transaction = Transaction(
                title: exportTransaction.title,
                amount: Decimal(string: exportTransaction.amount) ?? 0,
                type: txType,
                date: exportTransaction.date,
                note: exportTransaction.note ?? "",
                account: account,
                toAccount: toAccount,
                category: resolvedCategory,
                isRecurring: exportTransaction.isRecurring ?? false,
                recurringRule: exportTransaction.recurringRuleID.flatMap { ruleByID[$0] },
                transactionCurrency: exportTransaction.transactionCurrency,
                exchangeRate: exportTransaction.exchangeRate.flatMap { Decimal(string: $0) },
                parentTransactionID: exportTransaction.parentTransactionID,
                importSourceID: exportTransaction.importSourceID
            )
            transaction.id = exportTransaction.id
            if let createdAt = exportTransaction.createdAt {
                transaction.createdAt = createdAt
            }
            context.insert(transaction)
            transactionByID[exportTransaction.id] = transaction
            importedTransactions += 1
        }

        for exportDebt in payload.debts {
            guard let debt = debtByID[exportDebt.id] else { continue }
            debt.linkedTransactions = exportDebt.linkedTransactionIDs.compactMap { transactionByID[$0] }
        }

        var importedShoppingList = 0
        for exportItem in payload.shoppingList {
            if merge, (try? context.fetch(FetchDescriptor<ShoppingListItem>()))?.contains(where: { $0.id == exportItem.id }) == true {
                continue
            }

            let item = ShoppingListItem(
                name: exportItem.name,
                price: exportItem.price.flatMap { Decimal(string: $0) },
                quantity: exportItem.quantity,
                isChecked: exportItem.isChecked,
                isParsed: exportItem.isParsed,
                rawText: exportItem.rawText,
                sortOrder: exportItem.sortOrder
            )
            item.id = exportItem.id
            item.createdAt = exportItem.createdAt
            context.insert(item)
            importedShoppingList += 1
        }

        if !merge, let settings = payload.settings {
            settings.apply()
        }

        try context.save()

        return ImportResult(
            accounts: accountByID.count,
            categories: categoryByID.count,
            transactions: importedTransactions,
            budgets: importedBudgets,
            goals: importedGoals,
            plannedPayments: importedPayments,
            debts: importedDebts,
            recurringRules: ruleByID.count,
            shoppingList: importedShoppingList,
            skippedDuplicates: skippedDuplicates
        )
    }
}
