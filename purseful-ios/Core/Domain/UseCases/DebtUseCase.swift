import Foundation

@MainActor
struct DebtUseCase {
    let repository: DataRepositoryProtocol

    func saveExisting(_ debt: Debt) throws {
        if debt.createsLinkedTransactions {
            DebtService.syncOpeningTransaction(for: debt, context: repository.context)
        }
        try repository.save()
        NotificationScheduler.syncAfterSave(context: repository.context)
    }

    func create(
        _ debt: Debt,
        account: Account?,
        openingDate: Date
    ) throws {
        repository.insert(debt)
        if debt.createsLinkedTransactions, let account {
            _ = DebtService.recordOpening(debt: debt, account: account, date: openingDate, context: repository.context)
        }
        try repository.save()
        NotificationScheduler.syncAfterSave(context: repository.context)
    }

    func delete(_ debt: Debt) throws {
        DebtService.deleteDebt(debt, context: repository.context)
        try repository.save()
        NotificationScheduler.syncAfterSave(context: repository.context)
    }

    func recordRepayment(
        debt: Debt,
        amount: Decimal,
        account: Account?,
        date: Date
    ) throws {
        DebtService.recordRepayment(
            debt: debt,
            amount: amount,
            account: account,
            date: date,
            context: repository.context
        )
        try repository.save()
        NotificationScheduler.syncAfterSave(context: repository.context)
    }
}
