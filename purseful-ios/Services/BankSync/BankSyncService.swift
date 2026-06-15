import Foundation
import SwiftData

struct RawBankTransaction: Identifiable, Hashable {
    let id: String
    let amount: Decimal
    let date: Date
    let description: String
    let currency: String
}

protocol BankSyncService {
    func connect(institutionId: String) async throws -> String
    func fetchTransactions(connectionId: String, since: Date?) async throws -> [RawBankTransaction]
    func disconnect(connectionId: String) async throws
}

enum BankTransactionDedup {
    static func hash(amount: Decimal, date: Date, description: String) -> String {
        let day = Calendar.current.startOfDay(for: date)
        let normalized = description.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(amount)|\(day.timeIntervalSince1970)|\(normalized)"
    }

    static func isDuplicate(
        raw: RawBankTransaction,
        existing: [Transaction]
    ) -> Bool {
        let rawHash = hash(amount: raw.amount, date: raw.date, description: raw.description)
        return existing.contains { transaction in
            hash(amount: transaction.amount, date: transaction.date, description: transaction.title) == rawHash
        }
    }
}

@MainActor
enum BankTransactionImporter {
    static func importTransactions(
        _ rawTransactions: [RawBankTransaction],
        existing: [Transaction],
        account: Account,
        context: ModelContext
    ) -> Int {
        var imported = 0
        for raw in rawTransactions {
            guard !BankTransactionDedup.isDuplicate(raw: raw, existing: existing) else { continue }
            let transaction = Transaction(
                title: raw.description,
                amount: abs(raw.amount),
                type: raw.amount < 0 ? .expense : .income,
                date: raw.date,
                account: account,
                transactionCurrency: raw.currency
            )
            context.insert(transaction)
            imported += 1
        }
        try? context.save()
        return imported
    }
}
