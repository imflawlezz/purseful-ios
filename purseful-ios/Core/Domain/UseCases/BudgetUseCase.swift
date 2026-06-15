import Foundation
import SwiftData

@MainActor
struct BudgetUseCase {
    let repository: DataRepositoryProtocol

    func save(_ budget: Budget, isNew: Bool) throws {
        if isNew {
            repository.insert(budget)
            if budget.rolloverPeriodStart == nil {
                budget.rolloverPeriodStart = BudgetService.periodRange(for: budget).start
            }
        }
        if !budget.rollover {
            budget.rolloverAmount = 0
        }
        try repository.save()
    }

    func delete(_ budget: Budget) throws {
        NotificationService.shared.clearBudgetAlertState(for: budget.id)
        repository.delete(budget)
        try repository.save()
    }

    func processRollovers(
        transactions: [Transaction],
        exchangeRates: [String: Decimal],
        referenceDate: Date = Date()
    ) throws {
        let budgets = (try? repository.fetch(FetchDescriptor<Budget>())) ?? []
        let changed = BudgetService.processRollovers(
            budgets: budgets,
            transactions: transactions,
            baseCurrency: AppSettings.shared.baseCurrency,
            exchangeRates: exchangeRates,
            referenceDate: referenceDate
        )
        if changed {
            try repository.save()
        }
    }
}
