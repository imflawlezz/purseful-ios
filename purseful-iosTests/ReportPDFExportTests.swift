import PDFKit
import XCTest
@testable import purseful_ios

@MainActor
final class ReportPDFExportTests: XCTestCase {
    private let rates: [String: Decimal] = [
        "PLN": 1,
        "EUR": 0.23,
        "USD": 0.25
    ]

    func testSplitTransactionExpandsIntoMultipleLedgerLines() {
        let account = Account(name: "Wallet", type: .cash, currency: "PLN")
        let food = Category(name: "Food", type: .expense)
        let drinks = Category(name: "Drinks", type: .expense)

        let parent = Transaction(
            title: "Dinner",
            amount: 100,
            type: .expense,
            date: Date(),
            account: account,
            category: food
        )
        parent.id = UUID()

        let drinksChild = Transaction(
            title: "Dinner",
            amount: 40,
            type: .expense,
            date: Date(),
            account: account,
            category: drinks,
            parentTransactionID: parent.id
        )

        let result = ReportSummaryBuilder.build(
            transactions: [parent, drinksChild],
            from: Date.distantPast,
            through: Date.distantFuture,
            baseCurrency: "PLN",
            exchangeRates: rates
        )

        XCTAssertEqual(result.lines.count, 2)
        XCTAssertEqual(Set(result.lines.map(\.categoryName)), Set(["Food", "Drinks"]))

        let foodLine = result.lines.first { $0.categoryName == "Food" }
        let drinksLine = result.lines.first { $0.categoryName == "Drinks" }
        XCTAssertNotNil(foodLine)
        XCTAssertNotNil(drinksLine)
        XCTAssertTrue(foodLine?.amountLabel.contains("60") == true, "Food remainder should be 60, got \(foodLine?.amountLabel ?? "nil")")
        XCTAssertTrue(drinksLine?.amountLabel.contains("40") == true, "Drinks split should be 40, got \(drinksLine?.amountLabel ?? "nil")")
        XCTAssertFalse(result.lines.contains { $0.categoryName == "Other Expense" })
    }

    func testSpendingTrendLabelForKnownAmounts() {
        let calendar = Calendar.current
        let periodEnd = calendar.startOfDay(for: Date())
        let periodStart = calendar.date(byAdding: .day, value: -6, to: periodEnd)!
        let previousEnd = calendar.date(byAdding: .day, value: -1, to: periodStart)!
        let previousStart = calendar.date(byAdding: .day, value: -6, to: previousEnd)!

        let account = Account(name: "Wallet", type: .cash, currency: "PLN")
        let category = Category(name: "Food", type: .expense)

        let current = Transaction(
            title: "Groceries",
            amount: 150,
            type: .expense,
            date: periodStart,
            account: account,
            category: category
        )
        let previous = Transaction(
            title: "Groceries",
            amount: 100,
            type: .expense,
            date: previousStart,
            account: account,
            category: category
        )

        let result = ReportSummaryBuilder.build(
            transactions: [current, previous],
            from: periodStart,
            through: periodEnd,
            baseCurrency: "PLN",
            exchangeRates: rates
        )

        XCTAssertTrue(result.summary.spendingTrendLabel.contains("+50%"))
    }

    func testExportProducesValidPDFWithExpectedContent() throws {
        let summary = ReportSummary(
            periodLabel: "01.01.2026 – 31.01.2026",
            generatedAt: Date(timeIntervalSince1970: 1_767_225_600),
            baseCurrency: "PLN",
            totalIncome: 1000,
            totalExpenses: 400,
            netCashFlow: 600,
            transactionCount: 1,
            spendingTrendLabel: "vs previous period: 0%",
            categories: [ReportCategoryRow(name: "Food", amount: 400, sharePercent: 100)]
        )
        let lines = [
            ReportPDFLine(
                id: UUID(),
                date: Date(timeIntervalSince1970: 1_767_225_600),
                dateTimeLabel: "15.01.26 12:00",
                title: "Morning Coffee",
                accountLabel: "Wallet",
                categoryName: "Food",
                amountLabel: "-12.00 zł"
            )
        ]

        let url = try ReportPDFExportService.export(summary: summary, lines: lines)
        let data = try Data(contentsOf: url)

        XCTAssertGreaterThan(data.count, 0)
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "%PDF")

        let document = PDFDocument(url: url)
        XCTAssertNotNil(document)
        let extracted = document?.string ?? ""
        XCTAssertTrue(extracted.contains("Purseful Report"))
        XCTAssertTrue(extracted.contains("Morning Coffee"))
        XCTAssertTrue(extracted.contains("01.01.2026"))
        XCTAssertTrue(extracted.contains("100%"))
    }
}
