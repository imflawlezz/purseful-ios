import Foundation

@MainActor
struct PlannedPaymentUseCase {
    let repository: DataRepositoryProtocol

    func save(_ payment: PlannedPayment, isNew: Bool, createRecurringRuleIfNeeded: Bool) throws {
        if payment.type == .transfer {
            payment.category = nil
        } else {
            payment.category = CategoryService.resolvedCategory(
                payment.category,
                for: payment.type,
                context: repository.context
            )
        }

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

    func makePaidTransaction(from payment: PlannedPayment, date: Date = Date()) -> Transaction {
        Transaction(
            title: payment.name,
            amount: payment.amount,
            type: payment.type,
            date: date,
            note: payment.note,
            account: payment.account,
            toAccount: payment.type == .transfer ? payment.toAccount : nil,
            category: CategoryService.resolvedCategory(
                payment.category,
                for: payment.type,
                context: repository.context
            )
        )
    }

    func markPaid(_ payment: PlannedPayment, transaction: Transaction) throws {
        repository.insert(transaction)
        payment.lastPaidDate = Date()
        payment.nextDueDate = PaymentFrequencyHelper.nextDate(after: payment.nextDueDate, frequency: payment.frequency)
        if payment.frequency == .once { payment.isActive = false }
        try repository.save()
        NotificationScheduler.syncAfterSave(context: repository.context)
    }

    func markPaid(from payment: PlannedPayment, date: Date = Date()) throws {
        try markPaid(payment, transaction: makePaidTransaction(from: payment, date: date))
    }
}
