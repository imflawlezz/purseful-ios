import Foundation

@MainActor
struct ImportExportUseCase {
    let repository: DataRepositoryProtocol

    func exportJSON(
        transactions: [Transaction],
        accounts: [Account],
        categories: [Category],
        budgets: [Budget],
        goals: [Goal],
        plannedPayments: [PlannedPayment],
        debts: [Debt],
        recurringRules: [RecurringRule],
        shoppingList: [ShoppingListItem]
    ) throws -> Data {
        try ExportService.exportJSON(
            transactions: transactions,
            accounts: accounts,
            categories: categories,
            budgets: budgets,
            goals: goals,
            plannedPayments: plannedPayments,
            debts: debts,
            recurringRules: recurringRules,
            shoppingList: shoppingList
        )
    }

    func importJSON(data: Data, merge: Bool) throws -> ImportService.ImportResult {
        let result = try ImportService.importJSON(
            data: data,
            context: repository.context,
            merge: merge
        )
        Task { await NotificationScheduler.syncAll(context: repository.context) }
        return result
    }

    func clearAllData() throws {
        try PursefulWebImportService.clearAllData(context: repository.context)
        WidgetDataSync.update(accounts: [], transactions: [], budgets: [])
    }

    func syncWidgets(accounts: [Account], transactions: [Transaction], budgets: [Budget]) {
        WidgetDataSync.update(accounts: accounts, transactions: transactions, budgets: budgets)
    }
}
