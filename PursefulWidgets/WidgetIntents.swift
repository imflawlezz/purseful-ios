import AppIntents
import WidgetKit

struct AccountEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Account")
    static var defaultQuery = AccountEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct AccountEntityQuery: EntityQuery {
    func entities(for identifiers: [AccountEntity.ID]) async throws -> [AccountEntity] {
        let accounts = WidgetDataSync.loadSnapshot().accounts
        return identifiers.compactMap { id in
            accounts.first { $0.id == id }.map { AccountEntity(id: $0.id, name: $0.name) }
        }
    }

    func suggestedEntities() async throws -> [AccountEntity] {
        WidgetDataSync.loadSnapshot().accounts.map { AccountEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() async -> AccountEntity? {
        try? await suggestedEntities().first
    }
}

struct BudgetEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Budget")
    static var defaultQuery = BudgetEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct BudgetEntityQuery: EntityQuery {
    func entities(for identifiers: [BudgetEntity.ID]) async throws -> [BudgetEntity] {
        let budgets = WidgetDataSync.loadSnapshot().budgets
        return identifiers.compactMap { id in
            budgets.first { $0.id == id }.map { BudgetEntity(id: $0.id, name: $0.name) }
        }
    }

    func suggestedEntities() async throws -> [BudgetEntity] {
        WidgetDataSync.loadSnapshot().budgets.map { BudgetEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() async -> BudgetEntity? {
        try? await suggestedEntities().first
    }
}

struct SelectAccountIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Account"
    static var description = IntentDescription("Main account for Balances.")

    @Parameter(title: "Account")
    var account: AccountEntity?

    init() {}

    init(account: AccountEntity?) {
        self.account = account
    }
}

struct SelectBudgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Budget"
    static var description = IntentDescription("Which budget to show.")

    @Parameter(title: "Budget")
    var budget: BudgetEntity?

    init() {}

    init(budget: BudgetEntity?) {
        self.budget = budget
    }
}
