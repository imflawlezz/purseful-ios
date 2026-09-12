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

    func testBalancesByAccountIDMatchesPerAccountScan() {
        let cash = Account(name: "Cash", type: .cash, currency: "PLN", initialBalance: 100)
        let card = Account(name: "Card", type: .creditCard, currency: "PLN", initialBalance: 0)
        let income = Transaction(title: "Pay", amount: 50, type: .income, account: cash)
        let expense = Transaction(title: "Shop", amount: 20, type: .expense, account: card)
        let transfer = Transaction(
            title: "Move",
            amount: 10,
            type: .transfer,
            account: cash,
            toAccount: card
        )
        let transactions = [income, expense, transfer]

        let balances = BalanceCalculator.balancesByAccountID(
            accounts: [cash, card],
            transactions: transactions
        )

        XCTAssertEqual(
            balances[cash.id],
            BalanceCalculator.currentBalance(for: cash, transactions: transactions)
        )
        XCTAssertEqual(
            balances[card.id],
            BalanceCalculator.currentBalance(for: card, transactions: transactions)
        )
        XCTAssertEqual(balances[cash.id], 140)
        XCTAssertEqual(balances[card.id], -10)
    }

    func testNetWorthHistoryWalksBackwardFromCurrentBalances() {
        let cash = Account(name: "Cash", type: .cash, currency: "PLN", initialBalance: 100)
        cash.includeInTotal = true
        let day0 = Calendar.current.startOfDay(for: Date())
        let day1 = Calendar.current.date(byAdding: .day, value: 1, to: day0) ?? day0
        let day2 = Calendar.current.date(byAdding: .day, value: 2, to: day0) ?? day0

        let income = Transaction(title: "Pay", amount: 50, type: .income, date: day1, account: cash)
        let expense = Transaction(title: "Shop", amount: 20, type: .expense, date: day2, account: cash)
        let current = BalanceCalculator.balancesByAccountID(
            accounts: [cash],
            transactions: [income, expense]
        )

        let points = BalanceCalculator.netWorthHistory(
            sampleDates: [day0, day1, day2],
            accounts: [cash],
            currentBalances: current,
            laterTransactions: [income, expense],
            baseCurrency: "PLN",
            exchangeRates: ["PLN": 1]
        )

        XCTAssertEqual(points.map(\.date), [day0, day1, day2])
        XCTAssertEqual(points[0].value, 100)
        XCTAssertEqual(points[1].value, 150)
        XCTAssertEqual(points[2].value, 130)
    }
}
