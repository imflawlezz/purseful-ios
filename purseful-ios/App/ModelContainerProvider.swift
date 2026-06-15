import Foundation
import SwiftData

enum ModelContainerProvider {
    static let schema = Schema([
        Account.self,
        Transaction.self,
        Category.self,
        Budget.self,
        PlannedPayment.self,
        Debt.self,
        RecurringRule.self,
        Goal.self,
        BankConnection.self,
        ShoppingListItem.self
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        do {
            return try createContainer(inMemory: inMemory)
        } catch {
            guard !inMemory else { throw error }
            removePersistentStore()
            return try createContainer(inMemory: false)
        }
    }

    private static func createContainer(inMemory: Bool) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier
        ) {
            let storeURL = groupURL.appendingPathComponent("Purseful.store")
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func removePersistentStore() {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier
        ) else { return }

        let storeURL = groupURL.appendingPathComponent("Purseful.store")
        let relatedURLs = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]

        for url in relatedURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @MainActor
    static var preview: ModelContainer = {
        let container = try! makeContainer(inMemory: true)
        SeedDataService.seedIfNeeded(context: container.mainContext, force: true)
        return container
    }()
}
