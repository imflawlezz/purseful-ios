import XCTest
@testable import purseful_ios

final class BalanceCalculatorTests: XCTestCase {
    private let rates: [String: Decimal] = [
        "PLN": 1,
        "EUR": 0.23,
        "USD": 0.25
    ]

    func testConvertForeignToBase() {
        let result = BalanceCalculator.convert(100, from: "EUR", to: "PLN", rates: rates)
        XCTAssertEqual(NSDecimalNumber(decimal: result).doubleValue, 434.78, accuracy: 0.1)
    }

    func testCategorySpendingUsesSplitChildren() {
        let parent = Transaction(title: "Dinner", amount: 100, type: .expense, date: Date())
        parent.id = UUID()

        let food = Category(name: "Food", type: .expense)
        let drinks = Category(name: "Drinks", type: .expense)

        let child = Transaction(
            title: "Dinner",
            amount: 40,
            type: .expense,
            date: Date(),
            category: drinks,
            parentTransactionID: parent.id
        )
        parent.category = food

        let totals = BalanceCalculator.categorySpending(
            transactions: [parent, child],
            from: Date.distantPast,
            through: Date.distantFuture,
            baseCurrency: "PLN",
            exchangeRates: rates
        )

        XCTAssertEqual(totals["Food"], 60)
        XCTAssertEqual(totals["Drinks"], 40)
    }

    func testConvertBaseToForeign() {
        let result = BalanceCalculator.convert(100, from: "PLN", to: "EUR", rates: rates)
        XCTAssertEqual(NSDecimalNumber(decimal: result).doubleValue, 23, accuracy: 0.01)
    }

    func testConvertedAmountUsesStoredExchangeRate() {
        let account = Account(name: "Wallet", type: .cash, currency: "PLN")
        let transaction = Transaction(
            title: "Hotel",
            amount: 100,
            type: .expense,
            account: account,
            transactionCurrency: "EUR",
            exchangeRate: 4.3
        )

        let converted = BalanceCalculator.convertedAmount(
            transaction.amount,
            for: transaction,
            baseCurrency: "PLN",
            exchangeRates: rates
        )

        XCTAssertEqual(converted, 430)
    }

    func testDayNetCashFlowConvertsIntoBaseCurrency() {
        let plnAccount = Account(name: "Cash", type: .cash, currency: "PLN")
        let expense = Transaction(
            title: "Rent",
            amount: 1118,
            type: .expense,
            account: plnAccount
        )
        let groceries = Transaction(
            title: "Food",
            amount: 27.77,
            type: .expense,
            account: plnAccount
        )

        let total = BalanceCalculator.dayNetCashFlow(
            transactions: [expense, groceries],
            baseCurrency: "EUR",
            exchangeRates: rates
        )

        // rates: EUR=0.23, PLN=1 → PLN→EUR = amount * 0.23
        XCTAssertEqual(
            NSDecimalNumber(decimal: total).doubleValue,
            -263.5271,
            accuracy: 0.01
        )
    }
}
