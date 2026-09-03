import SwiftData
import Testing
@testable import purseful_ios

@MainActor
struct TransactionUseCaseQuickExpenseTests {
    private func makeUseCase() throws -> (ModelContext, TransactionUseCase) {
        let container = try ModelContainerProvider.makeContainer(inMemory: true)
        let context = ModelContext(container)
        return (context, TransactionUseCase(repository: SwiftDataRepository(context: context)))
    }

    @Test func addQuickExpenseUsesDefaultAccountAndCategory() throws {
        let (context, useCase) = try makeUseCase()
        SeedDataService.ensureSystemCategories(context: context)

        let cash = Account(name: "Cash", type: .cash, currency: "PLN")
        let card = Account(name: "Card", type: .creditCard, currency: "PLN")
        context.insert(cash)
        context.insert(card)
        AppSettings.shared.defaultAccountID = card.id

        let food = Category(name: "Food", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        context.insert(food)
        try context.save()

        let transaction = try useCase.addQuickExpense(amount: 12.5, categoryID: food.id)

        #expect(transaction.amount == 12.5)
        #expect(transaction.type == .expense)
        #expect(transaction.account?.id == card.id)
        #expect(transaction.category?.id == food.id)
        #expect(transaction.title == food.name)

        AppSettings.shared.defaultAccountID = nil
    }

    @Test func addQuickExpenseRejectsNonPositiveAmount() throws {
        let (context, useCase) = try makeUseCase()
        SeedDataService.ensureSystemCategories(context: context)
        context.insert(Account(name: "Cash", type: .cash, currency: "USD"))
        let category = try #require(
            Category.userSelectable(try context.fetch(FetchDescriptor<Category>()), type: .expense).first
        )

        #expect(throws: TransactionUseCase.QuickExpenseError.invalidAmount) {
            try useCase.addQuickExpense(amount: 0, categoryID: category.id)
        }
    }

    @Test func addQuickExpenseRequiresAnAccount() throws {
        let (context, useCase) = try makeUseCase()
        SeedDataService.ensureSystemCategories(context: context)
        let category = try #require(
            Category.userSelectable(try context.fetch(FetchDescriptor<Category>()), type: .expense).first
        )

        #expect(throws: TransactionUseCase.QuickExpenseError.noAccount) {
            try useCase.addQuickExpense(amount: 5, categoryID: category.id)
        }
    }
}
