import Foundation
import SwiftData

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

    func refreshExchangeRates(appState: AppState) async {
        await appState.refreshExchangeRates()
        let rates = appState.resolvedExchangeRates()
        let transactions = (try? repository.fetch(FetchDescriptor<Transaction>())) ?? []
        let accounts = (try? repository.fetch(FetchDescriptor<Account>())) ?? []
        let allBudgets = (try? repository.fetch(FetchDescriptor<Budget>())) ?? []
        await refresh(
            accounts: accounts,
            transactions: transactions,
            budgets: allBudgets,
            exchangeRates: rates
        )
    }
}
