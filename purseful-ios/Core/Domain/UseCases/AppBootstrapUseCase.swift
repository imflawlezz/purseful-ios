import Foundation
import SwiftData

@MainActor
struct AppBootstrapUseCase {
    let repository: DataRepositoryProtocol
    let budgets: BudgetUseCase

    func runStartupTasks() async {
        SeedDataService.seedIfNeeded(context: repository.context)
        SeedDataService.ensureSystemCategories(context: repository.context)

        let accounts = (try? repository.fetch(FetchDescriptor<Account>())) ?? []
        AccountPreferences.ensureSortOrders(accounts: accounts, context: repository.context)

        let transactions = (try? repository.fetch(FetchDescriptor<Transaction>())) ?? []
        let exchangeRates = ExchangeRateCache.load(for: AppSettings.shared.baseCurrency)
        try? budgets.processRollovers(transactions: transactions, exchangeRates: exchangeRates)

        RecurrenceProcessor.processDueItems(context: repository.context)
        await NotificationScheduler.syncAll(context: repository.context)
    }
}
