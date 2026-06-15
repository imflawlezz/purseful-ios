import XCTest
@testable import purseful_ios

final class BudgetServiceTests: XCTestCase {
    func testProgressCalculation() {
        let progress = BudgetService.progress(spent: 80, limit: 100)
        XCTAssertEqual(progress, 0.8, accuracy: 0.001)
    }

    func testEffectiveLimitWithRollover() {
        let budget = Budget(name: "Food", amount: 100, rollover: true)
        budget.rolloverAmount = 25
        XCTAssertEqual(BudgetService.effectiveLimit(budget: budget), 125)
    }

    func testEffectiveLimitWithoutRolloverIgnoresCarryover() {
        let budget = Budget(name: "Food", amount: 100, rollover: false)
        budget.rolloverAmount = 25
        XCTAssertEqual(BudgetService.effectiveLimit(budget: budget), 100)
    }

    func testProgressColorThresholds() {
        XCTAssertEqual(BudgetService.progressColor(progress: 0.5, threshold: 0.8), "#34C759")
        XCTAssertEqual(BudgetService.progressColor(progress: 0.85, threshold: 0.8), "#FF9500")
        XCTAssertEqual(BudgetService.progressColor(progress: 1.1, threshold: 0.8), "#FF3B30")
    }

    func testProcessRolloversInitializesTrackingWithoutChangingAmount() {
        let budget = Budget(name: "Food", amount: 500, rollover: true)
        let changed = BudgetService.processRollovers(
            budgets: [budget],
            transactions: [],
            baseCurrency: "USD",
            exchangeRates: ["USD": 1]
        )
        XCTAssertTrue(changed)
        XCTAssertEqual(budget.rolloverAmount, 0)
        XCTAssertNotNil(budget.rolloverPeriodStart)
    }

    func testProcessRolloversCarriesUnusedAmountIntoNextPeriod() {
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        let lastMonthStart = calendar.dateInterval(of: .month, for: lastMonth)!.start

        let budget = Budget(name: "Food", amount: 500, rollover: true)
        budget.rolloverPeriodStart = lastMonthStart

        let account = Account(name: "Cash", type: .cash, currency: "USD")
        let category = Category(name: "Food", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        let transaction = Transaction(
            title: "Groceries",
            amount: 400,
            type: .expense,
            date: calendar.date(byAdding: .day, value: 5, to: lastMonthStart)!,
            account: account,
            category: category
        )

        let changed = BudgetService.processRollovers(
            budgets: [budget],
            transactions: [transaction],
            baseCurrency: "USD",
            exchangeRates: ["USD": 1]
        )

        XCTAssertTrue(changed)
        XCTAssertEqual(budget.rolloverAmount, 100)
        XCTAssertEqual(
            calendar.startOfDay(for: budget.rolloverPeriodStart!),
            calendar.startOfDay(for: BudgetService.periodRange(for: budget).start)
        )
    }

    func testProcessRolloversDoesNotCarryNegativeBalance() {
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        let lastMonthStart = calendar.dateInterval(of: .month, for: lastMonth)!.start

        let budget = Budget(name: "Food", amount: 500, rollover: true)
        budget.rolloverPeriodStart = lastMonthStart

        let account = Account(name: "Cash", type: .cash, currency: "USD")
        let category = Category(name: "Food", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        let transaction = Transaction(
            title: "Splurge",
            amount: 650,
            type: .expense,
            date: calendar.date(byAdding: .day, value: 5, to: lastMonthStart)!,
            account: account,
            category: category
        )

        BudgetService.processRollovers(
            budgets: [budget],
            transactions: [transaction],
            baseCurrency: "USD",
            exchangeRates: ["USD": 1]
        )

        XCTAssertEqual(budget.rolloverAmount, 0)
    }

    func testProcessRolloversClearsCarryoverWhenDisabled() {
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        let lastMonthStart = calendar.dateInterval(of: .month, for: lastMonth)!.start

        let budget = Budget(name: "Food", amount: 500, rollover: false)
        budget.rolloverAmount = 75
        budget.rolloverPeriodStart = lastMonthStart

        BudgetService.processRollovers(
            budgets: [budget],
            transactions: [],
            baseCurrency: "USD",
            exchangeRates: ["USD": 1]
        )

        XCTAssertEqual(budget.rolloverAmount, 0)
    }

    func testProcessRolloversSkipsCustomPeriodBudgets() {
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        let lastMonthStart = calendar.dateInterval(of: .month, for: lastMonth)!.start

        let budget = Budget(
            name: "Trip",
            amount: 1000,
            period: .custom,
            rollover: true,
            customStartDate: lastMonthStart,
            customEndDate: Date()
        )
        budget.rolloverPeriodStart = lastMonthStart
        budget.rolloverAmount = 50

        let changed = BudgetService.processRollovers(
            budgets: [budget],
            transactions: [],
            baseCurrency: "USD",
            exchangeRates: ["USD": 1]
        )

        XCTAssertFalse(changed)
        XCTAssertEqual(budget.rolloverAmount, 50)
        XCTAssertEqual(budget.rolloverPeriodStart, lastMonthStart)
    }
}
