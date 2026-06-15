import Foundation

@MainActor
struct DashboardRefreshUseCase {
    let repository: DataRepositoryProtocol
    let budgets: BudgetUseCase

    func refresh(
        accounts: [Account],
        transactions: [Transaction],
        budgets allBudgets: [Budget],
        exchangeRates: [String: Decimal]
    ) async {
        try? budgets.processRollovers(transactions: transactions, exchangeRates: exchangeRates)
        RecurrenceProcessor.processDueItems(context: repository.context)
        WidgetDataSync.update(accounts: accounts, transactions: transactions, budgets: allBudgets)
        await NotificationScheduler.syncAll(
            context: repository.context,
            transactions: transactions,
            exchangeRates: exchangeRates
        )
    }
}
