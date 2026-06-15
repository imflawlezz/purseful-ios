import Foundation

@MainActor
struct PlannedPaymentUseCase {
    let repository: DataRepositoryProtocol

    func save(_ payment: PlannedPayment, isNew: Bool, createRecurringRuleIfNeeded: Bool) throws {
        if isNew {
            repository.insert(payment)
        }

        if createRecurringRuleIfNeeded && payment.autoCategorize && payment.recurringRule == nil {
            let rule = RecurringRule(frequency: payment.frequency)
            repository.insert(rule)
            payment.recurringRule = rule
        }

        try repository.save()
        NotificationScheduler.syncAfterSave(context: repository.context)
    }

    func delete(_ payment: PlannedPayment) throws {
        NotificationService.shared.cancelPaymentReminder(payment: payment)
        repository.delete(payment)
        try repository.save()
        NotificationScheduler.syncAfterSave(context: repository.context)
    }

    func markPaid(_ payment: PlannedPayment, transaction: Transaction) throws {
        repository.insert(transaction)
        payment.lastPaidDate = Date()
        payment.nextDueDate = PaymentFrequencyHelper.nextDate(after: payment.nextDueDate, frequency: payment.frequency)
        if payment.frequency == .once { payment.isActive = false }
        try repository.save()
        NotificationScheduler.syncAfterSave(context: repository.context)
    }
}
