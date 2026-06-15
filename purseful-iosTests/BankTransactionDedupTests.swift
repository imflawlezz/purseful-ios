import XCTest
@testable import purseful_ios

final class BankTransactionDedupTests: XCTestCase {
    func testHashIsStable() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let hash1 = BankTransactionDedup.hash(amount: 42.5, date: date, description: "Coffee Shop")
        let hash2 = BankTransactionDedup.hash(amount: 42.5, date: date, description: "coffee shop")
        XCTAssertEqual(hash1, hash2)
    }

    func testDetectsDuplicate() {
        let date = Date()
        let raw = RawBankTransaction(id: "1", amount: 10, date: date, description: "Test", currency: "USD")
        let existing = Transaction(title: "Test", amount: 10, date: date)
        XCTAssertTrue(BankTransactionDedup.isDuplicate(raw: raw, existing: [existing]))
    }
}
