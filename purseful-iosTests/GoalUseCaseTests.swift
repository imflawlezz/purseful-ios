import SwiftData
import Testing
@testable import purseful_ios

@MainActor
struct GoalUseCaseTests {
    private func makeContext() throws -> (ModelContext, GoalUseCase) {
        let container = try ModelContainerProvider.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let repository = SwiftDataRepository(context: context)
        return (context, GoalUseCase(repository: repository))
    }

    @Test func completionCreatesIncomeTransactionWhenLinkedAccountSet() throws {
        let (context, goals) = try makeContext()
        SeedDataService.ensureSystemCategories(context: context)

        let account = Account(name: "Savings", type: .savings, currency: "USD")
        context.insert(account)

        let goal = Goal(name: "Vacation", targetAmount: 500)
        goal.linkedAccount = account
        context.insert(goal)
        try context.save()

        try goals.contribute(goal, amount: 500)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        #expect(goal.isCompleted)
        #expect(transactions.count == 1)
        #expect(transactions.first?.title == "Goal: Vacation")
        #expect(transactions.first?.amount == 500)
        #expect(transactions.first?.type == .income)
        #expect(transactions.first?.account?.id == account.id)
    }

    @Test func completionWithoutLinkedAccountDoesNotCreateTransaction() throws {
        let (context, goals) = try makeContext()

        let goal = Goal(name: "Emergency", targetAmount: 200)
        context.insert(goal)
        try context.save()

        try goals.markComplete(goal)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        #expect(goal.isCompleted)
        #expect(transactions.isEmpty)
    }
}
