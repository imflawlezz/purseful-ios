import Foundation
import SwiftData
import Testing
@testable import purseful_ios

@MainActor
struct ImportExportTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainerProvider.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    @Test func exportJSONProducesValidV2Payload() throws {
        let data = try ExportService.exportJSON(
            transactions: [],
            accounts: [],
            categories: [],
            budgets: [],
            goals: [],
            plannedPayments: [],
            debts: [],
            recurringRules: [],
            shoppingList: []
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportPayload.self, from: data)
        #expect(payload.formatVersion == 2)
        #expect(payload.settings != nil)
    }

    @Test func v1PayloadDecodesWithDefaults() throws {
        let json = """
        {
          "formatVersion": 1,
          "exportedAt": "2026-06-11T12:00:00Z",
          "accounts": [],
          "categories": [],
          "transactions": [],
          "budgets": [],
          "goals": []
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportPayload.self, from: data)
        #expect(payload.formatVersion == 1)
        #expect(payload.plannedPayments.isEmpty)
        #expect(payload.debts.isEmpty)
        #expect(payload.shoppingList.isEmpty)
    }

    @Test func roundTripExportsAndImportsAllEntities() throws {
        let context = try makeContext()

        let account = Account(name: "Cash", type: .cash, currency: "USD", initialBalance: 100)
        let category = Category(name: "Food", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        let rule = RecurringRule(frequency: .monthly)
        let budget = Budget(name: "Food Budget", amount: 500, category: category)
        let goal = Goal(name: "Vacation", targetAmount: 1000)
        let payment = PlannedPayment(name: "Rent", amount: 1200, category: category, account: account)
        payment.recurringRule = rule
        let debt = Debt(name: "Loan", counterparty: "Bank", direction: .iOwe, originalAmount: 200, currency: "USD")
        let transaction = Transaction(title: "Groceries", amount: 25, type: .expense, account: account, category: category)
        let shoppingItem = ShoppingListItem(name: "Milk", price: 3, quantity: 2, isParsed: true, sortOrder: 0)

        context.insert(account)
        context.insert(category)
        context.insert(rule)
        context.insert(budget)
        context.insert(goal)
        context.insert(payment)
        context.insert(debt)
        context.insert(transaction)
        context.insert(shoppingItem)
        try context.save()

        let exportData = try ExportService.exportJSON(
            transactions: [transaction],
            accounts: [account],
            categories: [category],
            budgets: [budget],
            goals: [goal],
            plannedPayments: [payment],
            debts: [debt],
            recurringRules: [rule],
            shoppingList: [shoppingItem]
        )

        let importContext = try makeContext()
        let result = try ImportService.importJSON(data: exportData, context: importContext, merge: false)

        #expect(result.accounts == 1)
        #expect(result.categories == 1)
        #expect(result.transactions == 1)
        #expect(result.budgets == 1)
        #expect(result.goals == 1)
        #expect(result.plannedPayments == 1)
        #expect(result.debts == 1)
        #expect(result.recurringRules == 1)
        #expect(result.shoppingList == 1)

        let importedPayments = try importContext.fetch(FetchDescriptor<PlannedPayment>())
        #expect(importedPayments.first?.recurringRule?.id == rule.id)
    }

    @Test func categoryMergeUpdatesBudgetsAndPlannedPayments() throws {
        let context = try makeContext()

        let source = Category(name: "Old", icon: "tag", colorHex: "#FF0000", type: .expense)
        let target = Category(name: "New", icon: "tag.fill", colorHex: "#00FF00", type: .expense)
        let account = Account(name: "Cash", type: .cash, currency: "USD")
        let budget = Budget(name: "Budget", amount: 100, category: source)
        let payment = PlannedPayment(name: "Bill", amount: 10, category: source, account: account)
        let transaction = Transaction(title: "Test", amount: 5, type: .expense, account: account, category: source)

        context.insert(source)
        context.insert(target)
        context.insert(account)
        context.insert(budget)
        context.insert(payment)
        context.insert(transaction)
        try context.save()

        transaction.category = target
        budget.category = target
        payment.category = target
        context.delete(source)
        try context.save()

        #expect(transaction.category?.id == target.id)
        #expect(budget.category?.id == target.id)
        #expect(payment.category?.id == target.id)
        #expect((try context.fetch(FetchDescriptor<purseful_ios.Category>())).count == 1)
    }
}
