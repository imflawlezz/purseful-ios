import Foundation
import SwiftData

@MainActor
struct TransactionUseCase {
    let repository: DataRepositoryProtocol

    enum QuickExpenseError: Error, LocalizedError {
        case noAccount
        case categoryNotFound
        case invalidAmount

        var errorDescription: String? {
            switch self {
            case .noAccount:
                String(localized: "Add an account in Purseful before using Shortcuts.")
            case .categoryNotFound:
                String(localized: "That category isn’t available anymore.")
            case .invalidAmount:
                String(localized: "Enter an amount greater than zero.")
            }
        }
    }

    @discardableResult
    func addQuickExpense(amount: Decimal, categoryID: UUID) throws -> Transaction {
        guard amount > 0 else { throw QuickExpenseError.invalidAmount }

        let accounts = (try? repository.fetch(FetchDescriptor<Account>())) ?? []
        guard let account = AccountPreferences.preferredAccount(from: accounts) else {
            throw QuickExpenseError.noAccount
        }

        let categories = (try? repository.fetch(FetchDescriptor<Category>())) ?? []
        guard let category = Category.userSelectable(categories, type: .expense)
            .first(where: { $0.id == categoryID })
        else {
            throw QuickExpenseError.categoryNotFound
        }

        let transaction = Transaction(
            title: category.name,
            amount: amount,
            type: .expense,
            account: account,
            category: category
        )
        try save(transaction: transaction, isNew: true, splitLines: [])
        return transaction
    }

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
