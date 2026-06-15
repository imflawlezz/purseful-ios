import Foundation
import SwiftData

@MainActor
protocol DataRepositoryProtocol: AnyObject {
    var context: ModelContext { get }
    func save() throws
    func insert<T: PersistentModel>(_ model: T)
    func delete<T: PersistentModel>(_ model: T)
    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T]
}

@MainActor
extension DataRepositoryProtocol {
    func fetchAll<T: PersistentModel>(_ type: T.Type, sort: [SortDescriptor<T>] = []) throws -> [T] {
        var descriptor = FetchDescriptor<T>()
        descriptor.sortBy = sort
        return try fetch(descriptor)
    }
}
