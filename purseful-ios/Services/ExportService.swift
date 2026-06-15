import Foundation
import SwiftData

enum ExportService {
    static let formatVersion = 2

    @MainActor
    static func exportJSON(
        transactions: [Transaction],
        accounts: [Account],
        categories: [Category],
        budgets: [Budget],
        goals: [Goal],
        plannedPayments: [PlannedPayment],
        debts: [Debt],
        recurringRules: [RecurringRule],
        shoppingList: [ShoppingListItem],
        settings: ExportAppSettings? = nil
    ) throws -> Data {
        let payload = ExportPayload(
            formatVersion: formatVersion,
            exportedAt: Date(),
            accounts: accounts.map(ExportAccount.init),
            categories: categories.map(ExportCategory.init),
            transactions: transactions.filter { !$0.isSplitChild }.map(ExportTransaction.init),
            budgets: budgets.map(ExportBudget.init),
            goals: goals.map(ExportGoal.init),
            plannedPayments: plannedPayments.map(ExportPlannedPayment.init),
            debts: debts.map(ExportDebt.init),
            recurringRules: recurringRules.map(ExportRecurringRule.init),
            shoppingList: shoppingList.map(ExportShoppingListItem.init),
            settings: settings ?? .current
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }
}

struct ExportPayload: Codable {
    let formatVersion: Int
    let exportedAt: Date
    let accounts: [ExportAccount]
    let categories: [ExportCategory]
    let transactions: [ExportTransaction]
    let budgets: [ExportBudget]
    let goals: [ExportGoal]
    let plannedPayments: [ExportPlannedPayment]
    let debts: [ExportDebt]
    let recurringRules: [ExportRecurringRule]
    let shoppingList: [ExportShoppingListItem]
    let settings: ExportAppSettings?

    init(
        formatVersion: Int,
        exportedAt: Date,
        accounts: [ExportAccount],
        categories: [ExportCategory],
        transactions: [ExportTransaction],
        budgets: [ExportBudget],
        goals: [ExportGoal],
        plannedPayments: [ExportPlannedPayment] = [],
        debts: [ExportDebt] = [],
        recurringRules: [ExportRecurringRule] = [],
        shoppingList: [ExportShoppingListItem] = [],
        settings: ExportAppSettings? = nil
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions
        self.budgets = budgets
        self.goals = goals
        self.plannedPayments = plannedPayments
        self.debts = debts
        self.recurringRules = recurringRules
        self.shoppingList = shoppingList
        self.settings = settings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        accounts = try container.decode([ExportAccount].self, forKey: .accounts)
        categories = try container.decode([ExportCategory].self, forKey: .categories)
        transactions = try container.decode([ExportTransaction].self, forKey: .transactions)
        budgets = try container.decodeIfPresent([ExportBudget].self, forKey: .budgets) ?? []
        goals = try container.decodeIfPresent([ExportGoal].self, forKey: .goals) ?? []
        plannedPayments = try container.decodeIfPresent([ExportPlannedPayment].self, forKey: .plannedPayments) ?? []
        debts = try container.decodeIfPresent([ExportDebt].self, forKey: .debts) ?? []
        recurringRules = try container.decodeIfPresent([ExportRecurringRule].self, forKey: .recurringRules) ?? []
        shoppingList = try container.decodeIfPresent([ExportShoppingListItem].self, forKey: .shoppingList) ?? []
        settings = try container.decodeIfPresent(ExportAppSettings.self, forKey: .settings)
    }
}

struct ExportAppSettings: Codable {
    let baseCurrency: String
    let accentColorHex: String
    let defaultAccountID: UUID?
    let dailySpendCategoryIDs: [UUID]
    let dailySpendLookbackDays: Int
    let weeklySummaryEnabled: Bool

    @MainActor
    static var current: ExportAppSettings {
        let settings = AppSettings.shared
        return ExportAppSettings(
            baseCurrency: settings.baseCurrency,
            accentColorHex: settings.accentColorHex,
            defaultAccountID: settings.defaultAccountID,
            dailySpendCategoryIDs: Array(settings.dailySpendCategoryIDs),
            dailySpendLookbackDays: settings.dailySpendLookbackDays,
            weeklySummaryEnabled: settings.weeklySummaryEnabled
        )
    }

    @MainActor
    func apply() {
        let settings = AppSettings.shared
        settings.baseCurrency = baseCurrency
        settings.accentColorHex = accentColorHex
        settings.defaultAccountID = defaultAccountID
        settings.dailySpendCategoryIDs = Set(dailySpendCategoryIDs)
        settings.dailySpendLookbackDays = dailySpendLookbackDays
        settings.weeklySummaryEnabled = weeklySummaryEnabled
    }
}

struct ExportAccount: Codable {
    let id: UUID
    let name: String
    let type: String
    let currency: String
    let initialBalance: String
    let colorHex: String?
    let icon: String?
    let includeInTotal: Bool?
    let sortOrder: Int?
    let isHidden: Bool?

    @MainActor
    init(_ account: Account) {
        id = account.id
        name = account.name
        type = account.typeRaw
        currency = account.currency
        initialBalance = "\(account.initialBalance)"
        colorHex = account.colorHex
        icon = account.icon
        includeInTotal = account.includeInTotal
        sortOrder = account.sortOrder
        isHidden = account.isHidden
    }
}

struct ExportCategory: Codable {
    let id: UUID
    let name: String
    let type: String
    let icon: String
    let colorHex: String?
    let parentName: String?
    let sortOrder: Int?
    let isSystem: Bool?

    @MainActor
    init(_ category: Category) {
        id = category.id
        name = category.name
        type = category.typeRaw
        icon = category.icon
        colorHex = category.colorHex
        parentName = category.parent?.name
        sortOrder = category.sortOrder
        isSystem = category.isSystem
    }
}

struct ExportTransaction: Codable {
    let id: UUID
    let title: String
    let amount: String
    let type: String
    let date: Date
    let note: String?
    let categoryName: String?
    let accountName: String?
    let toAccountName: String?
    let transactionCurrency: String?
    let exchangeRate: String?
    let parentTransactionID: UUID?
    let importSourceID: String?
    let createdAt: Date?
    let isRecurring: Bool?
    let recurringRuleID: UUID?

    @MainActor
    init(_ transaction: Transaction) {
        id = transaction.id
        title = transaction.title
        amount = "\(transaction.amount)"
        type = transaction.typeRaw
        date = transaction.date
        note = transaction.note
        categoryName = transaction.category?.name
        accountName = transaction.account?.name
        toAccountName = transaction.toAccount?.name
        transactionCurrency = transaction.transactionCurrency
        exchangeRate = transaction.exchangeRate.map { "\($0)" }
        parentTransactionID = transaction.parentTransactionID
        importSourceID = transaction.importSourceID
        createdAt = transaction.createdAt
        isRecurring = transaction.isRecurring
        recurringRuleID = transaction.recurringRule?.id
    }
}

struct ExportBudget: Codable {
    let id: UUID
    let name: String
    let amount: String
    let period: String
    let categoryName: String?
    let rollover: Bool?
    let alertThreshold: Double?
    let customStartDate: Date?
    let customEndDate: Date?
    let rolloverAmount: String?
    let rolloverPeriodStart: Date?

    @MainActor
    init(_ budget: Budget) {
        id = budget.id
        name = budget.name
        amount = "\(budget.amount)"
        period = budget.periodRaw
        categoryName = budget.category?.name
        rollover = budget.rollover
        alertThreshold = budget.alertThreshold
        customStartDate = budget.customStartDate
        customEndDate = budget.customEndDate
        rolloverAmount = "\(budget.rolloverAmount)"
        rolloverPeriodStart = budget.rolloverPeriodStart
    }
}

struct ExportGoal: Codable {
    let id: UUID
    let name: String
    let targetAmount: String
    let currentAmount: String
    let icon: String?
    let colorHex: String?
    let targetDate: Date?
    let linkedAccountName: String?
    let note: String?
    let isCompleted: Bool?

    @MainActor
    init(_ goal: Goal) {
        id = goal.id
        name = goal.name
        targetAmount = "\(goal.targetAmount)"
        currentAmount = "\(goal.currentAmount)"
        icon = goal.icon
        colorHex = goal.colorHex
        targetDate = goal.targetDate
        linkedAccountName = goal.linkedAccount?.name
        note = goal.note
        isCompleted = goal.isCompleted
    }
}

struct ExportRecurringRule: Codable {
    let id: UUID
    let frequency: String
    let interval: Int
    let startDate: Date
    let endDate: Date?
    let daysOfWeek: [Int]

    @MainActor
    init(_ rule: RecurringRule) {
        id = rule.id
        frequency = rule.frequencyRaw
        interval = rule.interval
        startDate = rule.startDate
        endDate = rule.endDate
        daysOfWeek = rule.daysOfWeek
    }
}

struct ExportPlannedPayment: Codable {
    let id: UUID
    let name: String
    let note: String?
    let amount: String
    let frequency: String
    let type: String
    let nextDueDate: Date
    let isActive: Bool
    let autoCategorize: Bool
    let reminderDaysBefore: Int
    let lastPaidDate: Date?
    let categoryName: String?
    let accountName: String?
    let toAccountName: String?
    let recurringRuleID: UUID?

    @MainActor
    init(_ payment: PlannedPayment) {
        id = payment.id
        name = payment.name
        note = payment.note
        amount = "\(payment.amount)"
        frequency = payment.frequencyRaw
        type = payment.typeRaw
        nextDueDate = payment.nextDueDate
        isActive = payment.isActive
        autoCategorize = payment.autoCategorize
        reminderDaysBefore = payment.reminderDaysBefore
        lastPaidDate = payment.lastPaidDate
        categoryName = payment.category?.name
        accountName = payment.account?.name
        toAccountName = payment.toAccount?.name
        recurringRuleID = payment.recurringRule?.id
    }
}

struct ExportDebt: Codable {
    let id: UUID
    let name: String
    let counterparty: String
    let direction: String
    let originalAmount: String
    let remainingAmount: String
    let currency: String
    let dueDate: Date?
    let note: String?
    let createdAt: Date
    let createsLinkedTransactions: Bool
    let linkedTransactionIDs: [UUID]

    @MainActor
    init(_ debt: Debt) {
        id = debt.id
        name = debt.name
        counterparty = debt.counterparty
        direction = debt.directionRaw
        originalAmount = "\(debt.originalAmount)"
        remainingAmount = "\(debt.remainingAmount)"
        currency = debt.currency
        dueDate = debt.dueDate
        note = debt.note
        createdAt = debt.createdAt
        createsLinkedTransactions = debt.createsLinkedTransactions
        linkedTransactionIDs = (debt.linkedTransactions ?? []).map(\.id)
    }
}

struct ExportShoppingListItem: Codable {
    let id: UUID
    let sortOrder: Int
    let name: String
    let price: String?
    let quantity: Int
    let isChecked: Bool
    let isParsed: Bool
    let rawText: String
    let createdAt: Date

    @MainActor
    init(_ item: ShoppingListItem) {
        id = item.id
        sortOrder = item.sortOrder
        name = item.name
        price = item.price.map { "\($0)" }
        quantity = item.quantity
        isChecked = item.isChecked
        isParsed = item.isParsed
        rawText = item.rawText
        createdAt = item.createdAt
    }
}
