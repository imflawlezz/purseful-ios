import Foundation
import SwiftData

@MainActor
enum RecurrenceProcessor {
    static func processDueItems(context: ModelContext) {
        processPlannedPayments(context: context)
    }

    private static func processPlannedPayments(context: ModelContext) {
        let descriptor = FetchDescriptor<PlannedPayment>(
            predicate: #Predicate { $0.isActive }
        )
        guard let payments = try? context.fetch(descriptor) else { return }
        let today = Calendar.current.startOfDay(for: Date())

        for payment in payments where payment.autoCategorize && payment.nextDueDate <= today {
            let category = payment.type == .transfer
                ? nil
                : CategoryService.resolvedCategory(payment.category, for: payment.type, context: context)

            let transaction = Transaction(
                title: payment.name,
                amount: payment.amount,
                type: payment.type,
                date: payment.nextDueDate,
                note: payment.note,
                account: payment.account,
                toAccount: payment.type == .transfer ? payment.toAccount : nil,
                category: category
            )
            context.insert(transaction)

            if let rule = payment.recurringRule, let next = rule.nextDate(after: payment.nextDueDate) {
                payment.nextDueDate = next
            } else if payment.frequency != .once {
                payment.nextDueDate = PaymentFrequencyHelper.nextDate(
                    after: payment.nextDueDate,
                    frequency: payment.frequency
                )
            } else {
                payment.isActive = false
            }
        }
        try? context.save()
        NotificationScheduler.syncAfterSave(context: context)
    }
}

enum PlannedPaymentSchedule {
    static func occurrences(for payment: PlannedPayment, in month: Date, calendar: Calendar = .current) -> [Date] {
        guard payment.isActive else { return [] }
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }

        if payment.frequency == .once {
            let due = calendar.startOfDay(for: payment.nextDueDate)
            return interval.contains(due) ? [due] : []
        }

        var results: [Date] = []
        var date = calendar.startOfDay(for: payment.nextDueDate)
        var steps = 0

        while date < interval.start && steps < 512 {
            date = calendar.startOfDay(for: PaymentFrequencyHelper.nextDate(after: date, frequency: payment.frequency))
            steps += 1
        }

        steps = 0
        while date < interval.end && steps < 512 {
            if date >= interval.start {
                results.append(date)
            }
            date = calendar.startOfDay(for: PaymentFrequencyHelper.nextDate(after: date, frequency: payment.frequency))
            steps += 1
        }
        return results
    }

    static func currentPeriodStart(
        for frequency: PaymentFrequency,
        calendar: Calendar = .current,
        reference: Date = Date()
    ) -> Date {
        let day = calendar.startOfDay(for: reference)
        switch frequency {
        case .once:
            return day
        case .daily:
            return day
        case .weekly, .biweekly:
            return calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day
        case .monthly:
            return calendar.dateInterval(of: .month, for: day)?.start ?? day
        case .yearly:
            return calendar.dateInterval(of: .year, for: day)?.start ?? day
        }
    }

    static func isPaidInCurrentPeriod(_ payment: PlannedPayment, calendar: Calendar = .current) -> Bool {
        guard let lastPaidDate = payment.lastPaidDate else { return false }
        if payment.frequency == .once { return true }
        let paidDay = calendar.startOfDay(for: lastPaidDate)
        let periodStart = currentPeriodStart(for: payment.frequency, calendar: calendar)
        return paidDay >= periodStart
    }

    static func totalPlannedExpenses(
        from start: Date,
        through end: Date,
        payments: [PlannedPayment],
        baseCurrency: String,
        exchangeRates: [String: Decimal],
        calendar: Calendar = .current
    ) -> Decimal {
        totalPlannedNetWorthImpact(
            from: start,
            through: end,
            payments: payments.filter { $0.type == .expense },
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates,
            calendar: calendar
        )
    }

    static func totalPlannedNetWorthImpact(
        from start: Date,
        through end: Date,
        payments: [PlannedPayment],
        baseCurrency: String,
        exchangeRates: [String: Decimal],
        calendar: Calendar = .current
    ) -> Decimal {
        let rangeStart = calendar.startOfDay(for: start)
        let rangeEnd = calendar.startOfDay(for: end)
        guard rangeEnd >= rangeStart else { return 0 }

        var total: Decimal = 0
        var month = calendar.date(from: calendar.dateComponents([.year, .month], from: rangeStart)) ?? rangeStart
        var months = 0

        while month <= rangeEnd && months < 24 {
            for payment in payments where payment.isActive {
                for day in occurrences(for: payment, in: month, calendar: calendar) where day >= rangeStart && day <= rangeEnd {
                    let converted = BalanceCalculator.convertedPlannedPaymentAmount(
                        payment,
                        baseCurrency: baseCurrency,
                        exchangeRates: exchangeRates
                    )
                    switch payment.type {
                    case .expense:
                        total += converted
                    case .income:
                        total -= converted
                    case .transfer:
                        break
                    }
                }
            }
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = nextMonth
            months += 1
        }
        return total
    }
}

enum PaymentFrequencyHelper {
    static func nextDate(after date: Date, frequency: PaymentFrequency) -> Date {
        let calendar = Calendar.current
        switch frequency {
        case .once: return date
        case .daily: return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .biweekly: return calendar.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}
