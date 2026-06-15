import Foundation

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
        repository.delete(account)
        try repository.save()
    }
}
