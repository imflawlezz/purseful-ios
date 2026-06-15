import Foundation
import SwiftData
import UserNotifications

@MainActor
enum NotificationScheduler {
    static func syncAll(
        context: ModelContext,
        transactions: [Transaction]? = nil,
        exchangeRates: [String: Decimal]? = nil
    ) async {
        let status = await NotificationService.shared.authorizationStatus()
        guard status == .authorized else { return }

        let txs = transactions ?? ((try? context.fetch(FetchDescriptor<Transaction>())) ?? [])
        let budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        let payments = (try? context.fetch(FetchDescriptor<PlannedPayment>())) ?? []
        let debts = (try? context.fetch(FetchDescriptor<Debt>())) ?? []
        let goals = (try? context.fetch(FetchDescriptor<Goal>())) ?? []

        let baseCurrency = AppSettings.shared.baseCurrency
        let rates = exchangeRates ?? ExchangeRateCache.load(for: baseCurrency)

        NotificationService.shared.evaluateBudgetAlerts(
            budgets: budgets,
            transactions: txs,
            exchangeRates: rates
        )

        for payment in payments {
            NotificationService.shared.schedulePaymentReminder(payment: payment)
        }

        for debt in debts {
            NotificationService.shared.scheduleDebtReminder(debt: debt)
        }

        for goal in goals {
            NotificationService.shared.scheduleGoalReminder(goal: goal)
        }

        NotificationService.shared.scheduleWeeklySummary(
            transactions: txs,
            baseCurrency: baseCurrency,
            exchangeRates: rates
        )
    }

    static func syncAfterSave(
        context: ModelContext,
        exchangeRates: [String: Decimal]? = nil
    ) {
        Task {
            await syncAll(context: context, exchangeRates: exchangeRates)
        }
    }
}
