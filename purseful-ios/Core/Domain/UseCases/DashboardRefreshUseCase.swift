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
        WidgetDataSync.sync(using: repository)
        await NotificationScheduler.syncAll(
            context: repository.context,
            transactions: transactions,
            exchangeRates: exchangeRates
        )
    }
}
