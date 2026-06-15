import Foundation

@MainActor
struct ShoppingListUseCase {
    let repository: DataRepositoryProtocol

    func insert(_ item: ShoppingListItem) throws {
        repository.insert(item)
        try repository.save()
    }

    func delete(_ item: ShoppingListItem) throws {
        repository.delete(item)
        try repository.save()
    }

    func save() throws {
        try repository.save()
    }
}
