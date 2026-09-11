import Foundation
import SwiftData

@MainActor
struct TransactionUseCase {
    let repository: DataRepositoryProtocol

    enum QuickTransactionError: Error, LocalizedError {
        case noAccount
        case accountNotFound
        case categoryNotFound
        case invalidAmount
        case transferSameAccount

        var errorDescription: String? {
            switch self {
            case .noAccount:
                String(localized: "Add an account in Purseful before using Shortcuts.")
            case .accountNotFound:
                String(localized: "That account isn’t available anymore.")
            case .categoryNotFound:
                String(localized: "That category isn’t available anymore.")
            case .invalidAmount:
                String(localized: "Enter an amount greater than zero.")
            case .transferSameAccount:
                String(localized: "Choose two different accounts for a transfer.")
            }
        }
    }

    @discardableResult
    func addQuickExpense(amount: Decimal, categoryID: UUID, accountID: UUID? = nil) throws -> Transaction {
        try addQuickTransaction(
            amount: amount,
            type: .expense,
            categoryID: categoryID,
            accountID: accountID
        )
    }

    @discardableResult
    func addQuickIncome(amount: Decimal, categoryID: UUID, accountID: UUID? = nil) throws -> Transaction {
        try addQuickTransaction(
            amount: amount,
            type: .income,
            categoryID: categoryID,
            accountID: accountID
        )
    }

    @discardableResult
    func addQuickTransfer(amount: Decimal, fromAccountID: UUID, toAccountID: UUID) throws -> Transaction {
        guard amount > 0 else { throw QuickTransactionError.invalidAmount }
        guard fromAccountID != toAccountID else { throw QuickTransactionError.transferSameAccount }

        let fromAccount = try account(for: fromAccountID)
        let toAccount = try account(for: toAccountID)

        let transaction = Transaction(
            title: String(localized: "Transfer"),
            amount: amount,
            type: .transfer,
            account: fromAccount,
            toAccount: toAccount
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

    @discardableResult
    private func addQuickTransaction(
        amount: Decimal,
        type: TransactionType,
        categoryID: UUID,
        accountID: UUID?
    ) throws -> Transaction {
        guard amount > 0 else { throw QuickTransactionError.invalidAmount }

        let account = try resolveAccount(accountID)
        let categoryType: CategoryType = type == .income ? .income : .expense
        let categories = (try? repository.fetch(FetchDescriptor<Category>())) ?? []
        guard let category = Category.userSelectable(categories, type: categoryType)
            .first(where: { $0.id == categoryID })
        else {
            throw QuickTransactionError.categoryNotFound
        }

        let transaction = Transaction(
            title: category.name,
            amount: amount,
            type: type,
            account: account,
            category: category
        )
        try save(transaction: transaction, isNew: true, splitLines: [])
        return transaction
    }

    private func resolveAccount(_ accountID: UUID?) throws -> Account {
        let accounts = (try? repository.fetch(FetchDescriptor<Account>())) ?? []
        if let accountID {
            guard let account = accounts.first(where: { $0.id == accountID && !$0.isHidden }) else {
                throw QuickTransactionError.accountNotFound
            }
            return account
        }
        guard let account = AccountPreferences.preferredAccount(from: accounts) else {
            throw QuickTransactionError.noAccount
        }
        return account
    }

    private func account(for accountID: UUID) throws -> Account {
        try resolveAccount(accountID)
    }
}
