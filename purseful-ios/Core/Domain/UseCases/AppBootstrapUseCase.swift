import Foundation
import SwiftData
import AppIntents

@MainActor
struct AppBootstrapUseCase {
    let repository: DataRepositoryProtocol
    let budgets: BudgetUseCase

    func runStartupTasks() async {
        // First frame before store-heavy maintenance.
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(250))

        runCriticalStartupTasks()
        await Task.yield()
        await runDeferredStartupTasks()
    }

    func runCriticalStartupTasks() {
        let alreadySeeded = UserDefaults.standard.bool(forKey: AppConstants.hasSeededCategoriesKey)
        if !alreadySeeded {
            SeedDataService.seedIfNeeded(context: repository.context)
        }

        let accounts = (try? repository.fetch(FetchDescriptor<Account>())) ?? []
        AccountPreferences.ensureSortOrders(accounts: accounts, context: repository.context)
    }

    func runDeferredStartupTasks() async {
        // Category migrations are not on the first-paint path.
        SeedDataService.ensureSystemCategories(context: repository.context)
        await Task.yield()

        RecurrenceProcessor.processDueItems(context: repository.context)
        await Task.yield()

        let exchangeRates = ExchangeRateCache.load(for: AppSettings.shared.baseCurrency)
        let accounts = (try? repository.fetch(
            FetchDescriptor<Account>(sortBy: [SortDescriptor(\.sortOrder)])
        )) ?? []
        let transactions = (try? repository.fetch(
            FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )) ?? []
        let allBudgets = (try? repository.fetch(FetchDescriptor<Budget>())) ?? []
        let payments = (try? repository.fetch(
            FetchDescriptor<PlannedPayment>(sortBy: [SortDescriptor(\.nextDueDate)])
        )) ?? []
        let goals = (try? repository.fetch(FetchDescriptor<Goal>())) ?? []
        await Task.yield()

        try? budgets.processRollovers(transactions: transactions, exchangeRates: exchangeRates)
        await Task.yield()

        WidgetDataSync.update(
            accounts: accounts,
            transactions: transactions,
            budgets: allBudgets,
            plannedPayments: payments,
            goals: goals,
            exchangeRates: exchangeRates
        )
        await Task.yield()

        await NotificationScheduler.syncAll(
            context: repository.context,
            transactions: transactions,
            exchangeRates: exchangeRates
        )

        PursefulShortcuts.updateAppShortcutParameters()
    }
}
