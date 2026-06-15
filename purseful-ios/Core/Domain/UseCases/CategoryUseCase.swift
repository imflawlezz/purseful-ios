import Foundation
import SwiftData

@MainActor
struct CategoryUseCase {
    let repository: DataRepositoryProtocol

    func merge(source: Category, into target: Category) throws {
        let transactions = try repository.fetch(FetchDescriptor<Transaction>())
        let budgets = try repository.fetch(FetchDescriptor<Budget>())
        let payments = try repository.fetch(FetchDescriptor<PlannedPayment>())

        for transaction in transactions where transaction.category?.id == source.id {
            transaction.category = target
        }
        for budget in budgets where budget.category?.id == source.id {
            budget.category = target
        }
        for payment in payments where payment.category?.id == source.id {
            payment.category = target
        }

        repository.delete(source)
        try repository.save()
    }

    func delete(_ category: Category) throws {
        repository.delete(category)
        try repository.save()
    }

    func save(_ category: Category, isNew: Bool) throws {
        if isNew {
            repository.insert(category)
        }
        try repository.save()
    }
}
