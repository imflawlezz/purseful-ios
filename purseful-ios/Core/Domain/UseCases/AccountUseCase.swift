import Foundation
import SwiftUI

@MainActor
struct AccountUseCase {
    let repository: DataRepositoryProtocol

    func save(_ account: Account, isNew: Bool) throws {
        if isNew {
            repository.insert(account)
        }
        try repository.save()
    }

    func delete(_ account: Account) throws {
        AccountPreferences.clearDefaultIfNeeded(for: account)
        repository.delete(account)
        try repository.save()
    }

    func ensureSortOrders(accounts: [Account]) {
        AccountPreferences.ensureSortOrders(accounts: accounts, context: repository.context)
    }

    func moveAccounts(from source: IndexSet, to destination: Int, accounts: [Account]) {
        AccountPreferences.moveAccounts(
            from: source,
            to: destination,
            accounts: accounts,
            context: repository.context
        )
    }
}
