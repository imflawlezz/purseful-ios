import Foundation
import SwiftData
import Testing
@testable import purseful_ios

struct DailySpendCalculatorTests {
    @Test @MainActor func dailyAverageUsesSelectedCategoriesOnly() throws {
        let container = try ModelContainerProvider.makeContainer(inMemory: true)
        let context = container.mainContext

        let food = Category(name: "Food", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        let rent = Category(name: "Rent", icon: "house", colorHex: "#FF0000", type: .expense)
        let account = Account(name: "Wallet", currency: "PLN")
        context.insert(food)
        context.insert(rent)
        context.insert(account)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        context.insert(Transaction(
            title: "Groceries",
            amount: 40,
            type: .expense,
            date: today,
            account: account,
            category: food
        ))
        context.insert(Transaction(
            title: "Rent",
            amount: 826,
            type: .expense,
            date: yesterday,
            account: account,
            category: rent
        ))
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let average = DailySpendCalculator.dailyAverage(
            transactions: transactions,
            selectedCategoryIDs: [food.id],
            lookbackDays: 2,
            through: today,
            baseCurrency: "PLN",
            exchangeRates: ["PLN": 1]
        )

        #expect(average == Decimal(string: "20"))
    }

    @Test func projectedVariableSpendCountsDaysUntilSelectedDate() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let inThreeDays = calendar.date(byAdding: .day, value: 3, to: today)!

        let projected = DailySpendCalculator.projectedVariableSpend(
            dailyAverage: 50,
            from: today,
            through: inThreeDays,
            calendar: calendar
        )

        #expect(projected == Decimal(150))
    }
}
