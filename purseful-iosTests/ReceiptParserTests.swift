import XCTest
@testable import purseful_ios

final class ReceiptParserTests: XCTestCase {
    func testParsesPolishTotalKeyword() {
        let text = """
        BIEDRONKA
        ul. Testowa 1
        PARAGON FISKALNY
        CHLEB           4,99
        SUMA            4,99
        """
        let result = ReceiptParser.parse(text: text)
        XCTAssertEqual(result.total, 4.99)
        XCTAssertNotNil(result.merchant)
    }

    func testParsesDate() {
        let text = "Sklep\n12.03.2024\nTOTAL 19,50"
        let result = ReceiptParser.parse(text: text)
        XCTAssertNotNil(result.date)
    }

    func testSuggestsGroceriesForBiedronka() {
        let result = ReceiptParser.parse(text: "BIEDRONKA\nSUMA 10,00")
        XCTAssertEqual(result.suggestedCategory, "Groceries")
    }
}
