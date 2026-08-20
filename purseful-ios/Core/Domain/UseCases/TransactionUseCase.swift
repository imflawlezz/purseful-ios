import Foundation
import SwiftData

@MainActor
struct TransactionUseCase {
    let repository: DataRepositoryProtocol

    func save(
        transaction: Transaction,
        isNew: Bool,
        splitLines: [(category: Category, amount: Decimal)]
    ) throws {
        transaction.category = CategoryService.resolvedCategory(
            transaction.category,
            for: transaction.type,
            context: repository.context
        )

        if isNew {
            repository.insert(transaction)
        }

        let parentID = transaction.id
        let existingChildren = (try? repository.fetch(
            FetchDescriptor<Transaction>(predicate: #Predicate { $0.parentTransactionID == parentID })
        )) ?? []
        existingChildren.forEach { repository.delete($0) }

        if transaction.type != .transfer {
            for split in splitLines {
                let child = Transaction(
                    title: transaction.title,
                    amount: split.amount,
                    type: transaction.type,
                    date: transaction.date,
                    account: transaction.account,
                    category: split.category,
                    parentTransactionID: transaction.id
                )
                repository.insert(child)
            }
        }

        try repository.save()
        NotificationScheduler.syncAfterSave(context: repository.context)
        WidgetDataSync.sync(using: repository)
    }

    func delete(_ transaction: Transaction) throws {
        let parentID = transaction.id
        let children = (try? repository.fetch(
            FetchDescriptor<Transaction>(predicate: #Predicate { $0.parentTransactionID == parentID })
        )) ?? []
        children.forEach { repository.delete($0) }

        DebtService.handleLinkedTransactionDeletion(transaction, context: repository.context)
        repository.delete(transaction)
        try repository.save()
        NotificationScheduler.syncAfterSave(context: repository.context)
        WidgetDataSync.sync(using: repository)
    }

    func deleteMany(_ transactions: [Transaction]) throws {
        for transaction in transactions {
            try delete(transaction)
        }
    }
}
