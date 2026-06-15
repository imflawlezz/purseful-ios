import Foundation
import SwiftData
import Testing
@testable import purseful_ios

struct PursefulWebImportTests {
    @Test func parsesLocalDayDateAtStartOfDay() throws {
        let parsed = try #require(PursefulWebImportService.parseWebTransactionDates(
            date: "2025-11-28",
            createdAt: "2025-11-28T16:35:23.884Z"
        ))

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: parsed.transactionDate)

        #expect(components.year == 2025)
        #expect(components.month == 11)
        #expect(components.day == 28)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(parsed.createdAt > parsed.transactionDate)
    }

    @Test func rejectsInvalidDates() {
        #expect(PursefulWebImportService.parseWebTransactionDates(date: "not-a-date", createdAt: nil) == nil)
    }

    @Test func sortsSameDayTransactionsByCreatedAt() throws {
        let earlier = try #require(PursefulWebImportService.parseWebTransactionDates(
            date: "2025-12-16",
            createdAt: "2025-12-16T10:17:47.979Z"
        ))
        let later = try #require(PursefulWebImportService.parseWebTransactionDates(
            date: "2025-12-16",
            createdAt: "2025-12-16T10:18:23.044Z"
        ))

        #expect(earlier.transactionDate == later.transactionDate)
        #expect(earlier.createdAt < later.createdAt)
    }

    @Test @MainActor func decodesWebBackupPayload() throws {
        let json = """
        {
          "accounts": [{ "id": "a1", "name": "Wallet", "type": "cash", "currency": "PLN" }],
          "categories": [{ "id": "c1", "name": "Food & Dining", "type": "expense" }],
          "transactions": [{
            "id": "t1",
            "accountId": "a1",
            "categoryId": "c1",
            "type": "expense",
            "amount": 11.99,
            "currency": "PLN",
            "date": "2025-11-28",
            "createdAt": "2025-11-28T16:35:23.884Z"
          }]
        }
        """.data(using: .utf8)!

        let backup = try PursefulWebImportService.parseBackup(data: json)

        #expect(backup.accounts?.count == 1)
        #expect(backup.categories?.count == 1)
        #expect(backup.transactions?.count == 1)
        #expect(backup.accounts?.first?.name == "Wallet")
    }

    @Test @MainActor func importMatchesLegacyAccountBalance() throws {
        let json = """
        {
          "accounts": [{
            "id": "a1",
            "name": "Wallet",
            "type": "cash",
            "currency": "PLN",
            "balance": 12.77
          }],
          "categories": [{ "id": "c1", "name": "Shopping", "type": "expense" }],
          "transactions": [
            {
              "id": "t1",
              "accountId": "a1",
              "categoryId": "c1",
              "type": "income",
              "amount": 20,
              "currency": "PLN",
              "date": "2025-11-28",
              "createdAt": "2025-11-28T10:00:00.000Z"
            },
            {
              "id": "t2",
              "accountId": "a1",
              "categoryId": "c1",
              "type": "expense",
              "amount": 10,
              "currency": "PLN",
              "date": "2025-11-29",
              "createdAt": "2025-11-29T10:00:00.000Z"
            }
          ]
        }
        """.data(using: .utf8)!

        let container = try ModelContainerProvider.makeContainer(inMemory: true)
        let context = container.mainContext
        let backup = try PursefulWebImportService.parseBackup(data: json)
        let mappings = PursefulWebImportService.suggestedMappings(
            backup: backup,
            existingAccounts: [],
            existingCategories: []
        )

        _ = try PursefulWebImportService.importBackup(
            backup: backup,
            context: context,
            merge: false,
            mappings: mappings
        )

        let accounts = try context.fetch(FetchDescriptor<Account>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let wallet = try #require(accounts.first)

        let balance = BalanceCalculator.currentBalance(for: wallet, transactions: transactions)
        #expect(balance == Decimal(string: "12.77"))
        #expect(wallet.initialBalance == Decimal(string: "2.77"))
    }

    @Test @MainActor func mergeSkipsDuplicateWebTransactions() throws {
        let json = """
        {
          "accounts": [{
            "id": "a1",
            "name": "Wallet",
            "type": "cash",
            "currency": "PLN",
            "balance": 5
          }],
          "categories": [{ "id": "c1", "name": "Shopping", "type": "expense" }],
          "transactions": [{
            "id": "t1",
            "accountId": "a1",
            "categoryId": "c1",
            "type": "income",
            "amount": 5,
            "currency": "PLN",
            "date": "2025-11-28",
            "createdAt": "2025-11-28T10:00:00.000Z"
          }]
        }
        """.data(using: .utf8)!

        let container = try ModelContainerProvider.makeContainer(inMemory: true)
        let context = container.mainContext
        let backup = try PursefulWebImportService.parseBackup(data: json)
        let mappings = PursefulWebImportService.suggestedMappings(
            backup: backup,
            existingAccounts: [],
            existingCategories: []
        )

        _ = try PursefulWebImportService.importBackup(
            backup: backup,
            context: context,
            merge: false,
            mappings: mappings
        )

        let second = try PursefulWebImportService.importBackup(
            backup: backup,
            context: context,
            merge: true,
            mappings: mappings
        )

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        #expect(transactions.count == 1)
        #expect(second.skippedDuplicates == 1)
        #expect(second.transactions == 0)
    }
}
