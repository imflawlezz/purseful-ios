import Foundation
import SwiftData

/// Reuses the app `ModelContainer` when registered; otherwise opens the App Group store (cold Shortcut runs).
@MainActor
enum PursefulIntentRuntime {
    private static var registeredContainer: ModelContainer?

    static func register(_ container: ModelContainer) {
        registeredContainer = container
    }

    static func modelContainer() throws -> ModelContainer {
        if let registeredContainer {
            return registeredContainer
        }
        let container = try ModelContainerProvider.makeContainer()
        registeredContainer = container
        return container
    }

    static func transactions() throws -> TransactionUseCase {
        let container = try modelContainer()
        return TransactionUseCase(
            repository: SwiftDataRepository(context: container.mainContext)
        )
    }

    static func fetchCategories() throws -> [Category] {
        let context = try modelContainer().mainContext
        return try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    static func fetchAccounts() throws -> [Account] {
        let context = try modelContainer().mainContext
        let accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.sortOrder)]))
        return AccountPreferences.visibleAccounts(accounts)
    }
}
