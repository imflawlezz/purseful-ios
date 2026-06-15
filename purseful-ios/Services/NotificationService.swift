import Foundation
import UserNotifications

enum BudgetAlertLevel: String {
    case threshold
    case exceeded
}

enum NotificationHelpers {
    static func budgetAlertDedupKey(budgetID: UUID, periodStart: Date, level: BudgetAlertLevel) -> String {
        let day = Calendar.current.startOfDay(for: periodStart)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return "budgetAlert.\(budgetID.uuidString).\(formatter.string(from: day)).\(level.rawValue)"
    }

    static func nextMondayMorning(from date: Date = Date(), calendar: Calendar = .current) -> Date? {
        var components = DateComponents()
        components.weekday = 2
        components.hour = 9
        components.minute = 0
        return calendar.nextDate(
            after: date,
            matching: components,
            matchingPolicy: .nextTimePreservingSmallerComponents
        )
    }
}

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func evaluateBudgetAlerts(
        budgets: [Budget],
        transactions: [Transaction],
        exchangeRates: [String: Decimal]
    ) {
        let baseCurrency = AppSettings.shared.baseCurrency

        for budget in budgets {
            let spent = BudgetService.spentAmount(
                budget: budget,
                transactions: transactions,
                baseCurrency: baseCurrency,
                exchangeRates: exchangeRates
            )
            let limit = BudgetService.effectiveLimit(budget: budget)
            guard limit > 0 else { continue }

            let progress = BudgetService.progress(spent: spent, limit: limit)
            let periodStart = BudgetService.periodRange(for: budget).start

            if progress >= 1.0 {
                deliverBudgetAlertIfNeeded(
                    budget: budget,
                    progress: progress,
                    periodStart: periodStart,
                    level: .exceeded
                )
            } else if progress >= budget.alertThreshold {
                deliverBudgetAlertIfNeeded(
                    budget: budget,
                    progress: progress,
                    periodStart: periodStart,
                    level: .threshold
                )
            }
        }
    }

    func schedulePaymentReminder(payment: PlannedPayment) {
        let identifier = paymentNotificationID(payment.id)
        cancelNotification(id: identifier)

        guard payment.isActive else { return }
        if payment.frequency == .once, payment.lastPaidDate != nil { return }

        let calendar = Calendar.current
        let reminderDate = calendar.date(
            byAdding: .day,
            value: -payment.reminderDaysBefore,
            to: payment.nextDueDate
        ) ?? payment.nextDueDate

        guard reminderDate >= calendar.startOfDay(for: Date()) else { return }

        var components = calendar.dateComponents([.year, .month, .day], from: reminderDate)
        components.hour = 9

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Payment"
        content.body = "\(payment.name) is due on \(DateFormatters.short.string(from: payment.nextDueDate))."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelPaymentReminder(payment: PlannedPayment) {
        cancelNotification(id: paymentNotificationID(payment.id))
    }

    func scheduleDebtReminder(debt: Debt) {
        let identifier = debtNotificationID(debt.id)
        cancelNotification(id: identifier)

        guard let dueDate = debt.dueDate else { return }

        let calendar = Calendar.current
        let reminderDate = calendar.date(byAdding: .day, value: -1, to: dueDate) ?? dueDate
        guard reminderDate >= calendar.startOfDay(for: Date()) else { return }

        var components = calendar.dateComponents([.year, .month, .day], from: reminderDate)
        components.hour = 9

        let content = UNMutableNotificationContent()
        content.title = "Debt Due"
        content.body = "\(debt.name) with \(debt.counterparty) is due soon."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelDebtReminder(debt: Debt) {
        cancelNotification(id: debtNotificationID(debt.id))
    }

    func scheduleGoalReminder(goal: Goal) {
        let identifier = goalNotificationID(goal.id)
        cancelNotification(id: identifier)

        guard !goal.isCompleted, let targetDate = goal.targetDate else { return }

        let calendar = Calendar.current
        let reminderDate = calendar.date(byAdding: .day, value: -7, to: targetDate) ?? targetDate
        guard reminderDate >= calendar.startOfDay(for: Date()) else { return }

        var components = calendar.dateComponents([.year, .month, .day], from: reminderDate)
        components.hour = 9

        let content = UNMutableNotificationContent()
        content.title = "Goal Reminder"
        content.body = "\(goal.name) target date is \(DateFormatters.short.string(from: targetDate))."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelGoalReminder(goal: Goal) {
        cancelNotification(id: goalNotificationID(goal.id))
    }

    func scheduleWeeklySummary(
        transactions: [Transaction],
        baseCurrency: String,
        exchangeRates: [String: Decimal]
    ) {
        cancelWeeklySummary()

        guard AppSettings.shared.weeklySummaryEnabled else { return }
        guard let fireDate = NotificationHelpers.nextMondayMorning() else { return }
        guard fireDate > Date() else { return }

        let calendar = Calendar.current
        let mondayStart = calendar.startOfDay(for: fireDate)
        guard let periodStart = calendar.date(byAdding: .day, value: -7, to: mondayStart),
              let periodEnd = calendar.date(byAdding: .second, value: -1, to: mondayStart) else {
            return
        }

        let spent = BalanceCalculator.totalExpenses(
            transactions: transactions,
            from: periodStart,
            through: periodEnd,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)

        let content = UNMutableNotificationContent()
        content.title = "Weekly Summary"
        content.body = "Last week you spent \(CurrencyFormatter.format(spent, currencyCode: baseCurrency))."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: weeklySummaryID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelWeeklySummary() {
        cancelNotification(id: weeklySummaryID)
    }

    func clearBudgetAlertState(for budgetID: UUID) {
        let prefix = "budgetAlert.\(budgetID.uuidString)."
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    private let weeklySummaryID = "weekly-summary"

    private func paymentNotificationID(_ id: UUID) -> String { "payment-\(id.uuidString)" }
    private func debtNotificationID(_ id: UUID) -> String { "debt-\(id.uuidString)" }
    private func goalNotificationID(_ id: UUID) -> String { "goal-\(id.uuidString)" }

    private func deliverBudgetAlertIfNeeded(
        budget: Budget,
        progress: Double,
        periodStart: Date,
        level: BudgetAlertLevel
    ) {
        let dedupKey = NotificationHelpers.budgetAlertDedupKey(
            budgetID: budget.id,
            periodStart: periodStart,
            level: level
        )
        guard !UserDefaults.standard.bool(forKey: dedupKey) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Budget Alert"
        if level == .exceeded {
            content.body = "\(budget.name) has exceeded your limit."
        } else {
            content.body = "\(budget.name) is at \(Int(progress * 100))% of your limit."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "budget-\(budget.id.uuidString)-\(level.rawValue)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
        UserDefaults.standard.set(true, forKey: dedupKey)
    }
}
