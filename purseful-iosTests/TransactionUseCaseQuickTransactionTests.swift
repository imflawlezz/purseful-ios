import SwiftData
import Testing
@testable import purseful_ios

@MainActor
struct TransactionUseCaseQuickTransactionTests {
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

        AppSettings.shared.defaultAccountID = nil
    }

    @Test func addQuickExpenseUsesExplicitAccount() throws {
        let (context, useCase) = try makeUseCase()
        SeedDataService.ensureSystemCategories(context: context)

        let cash = Account(name: "Cash", type: .cash, currency: "PLN")
        let card = Account(name: "Card", type: .creditCard, currency: "PLN")
        context.insert(cash)
        context.insert(card)

        let food = Category(name: "Food", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        context.insert(food)
        try context.save()

        let transaction = try useCase.addQuickExpense(amount: 5, categoryID: food.id, accountID: cash.id)

        #expect(transaction.account?.id == cash.id)
    }

    @Test func addQuickIncomeUsesIncomeCategory() throws {
        let (context, useCase) = try makeUseCase()
        SeedDataService.ensureSystemCategories(context: context)

        let account = Account(name: "Cash", type: .cash, currency: "USD")
        context.insert(account)

        let salary = Category(name: "Salary", icon: "briefcase", colorHex: "#34C759", type: .income)
        context.insert(salary)
        try context.save()

        let transaction = try useCase.addQuickIncome(amount: 100, categoryID: salary.id, accountID: account.id)

        #expect(transaction.type == .income)
        #expect(transaction.category?.id == salary.id)
        #expect(transaction.account?.id == account.id)
    }

    @Test func addQuickTransferMovesBetweenAccounts() throws {
        let (context, useCase) = try makeUseCase()

        let cash = Account(name: "Cash", type: .cash, currency: "USD")
        let savings = Account(name: "Savings", type: .savings, currency: "USD")
        context.insert(cash)
        context.insert(savings)
        try context.save()

        let transaction = try useCase.addQuickTransfer(
            amount: 25,
            fromAccountID: cash.id,
            toAccountID: savings.id
        )

        #expect(transaction.type == .transfer)
        #expect(transaction.account?.id == cash.id)
        #expect(transaction.toAccount?.id == savings.id)
        #expect(transaction.category == nil)
    }

    @Test func addQuickExpenseRejectsNonPositiveAmount() throws {
        let (context, useCase) = try makeUseCase()
        SeedDataService.ensureSystemCategories(context: context)
        context.insert(Account(name: "Cash", type: .cash, currency: "USD"))
        let category = try #require(
            Category.userSelectable(try context.fetch(FetchDescriptor<Category>()), type: .expense).first
        )

        #expect(throws: TransactionUseCase.QuickTransactionError.invalidAmount) {
            try useCase.addQuickExpense(amount: 0, categoryID: category.id)
        }
    }

    @Test func addQuickTransferRejectsSameAccount() throws {
        let (context, useCase) = try makeUseCase()
        let account = Account(name: "Cash", type: .cash, currency: "USD")
        context.insert(account)
        try context.save()

        #expect(throws: TransactionUseCase.QuickTransactionError.transferSameAccount) {
            try useCase.addQuickTransfer(amount: 10, fromAccountID: account.id, toAccountID: account.id)
        }
    }

    @Test func addQuickExpenseRequiresAnAccount() throws {
        let (context, useCase) = try makeUseCase()
        SeedDataService.ensureSystemCategories(context: context)
        let category = try #require(
            Category.userSelectable(try context.fetch(FetchDescriptor<Category>()), type: .expense).first
        )

        #expect(throws: TransactionUseCase.QuickTransactionError.noAccount) {
            try useCase.addQuickExpense(amount: 5, categoryID: category.id)
        }
    }
}
