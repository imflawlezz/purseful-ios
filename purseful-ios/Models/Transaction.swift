import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID = UUID()
    var title: String = ""
    var note: String = ""
    var amount: Decimal = 0
    var typeRaw: String = TransactionType.expense.rawValue
    var date: Date = Date()
    var isRecurring: Bool = false
    var attachmentData: Data?
    var createdAt: Date = Date()
    var transactionCurrency: String?
    var exchangeRate: Decimal?
    var parentTransactionID: UUID?
    var importSourceID: String?

    var account: Account?
    var toAccount: Account?
    var category: Category?
    var recurringRule: RecurringRule?

    @Relationship(deleteRule: .nullify, inverse: \Debt.linkedTransactions)
    var linkedDebts: [Debt]?

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var isSplitChild: Bool {
        parentTransactionID != nil
    }

    init(
        title: String,
        amount: Decimal,
        type: TransactionType = .expense,
        date: Date = Date(),
        note: String = "",
        account: Account? = nil,
        toAccount: Account? = nil,
        category: Category? = nil,
        isRecurring: Bool = false,
        recurringRule: RecurringRule? = nil,
        attachmentData: Data? = nil,
        transactionCurrency: String? = nil,
        exchangeRate: Decimal? = nil,
        parentTransactionID: UUID? = nil,
        importSourceID: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.typeRaw = type.rawValue
        self.date = date
        self.note = note
        self.account = account
        self.toAccount = toAccount
        self.category = category
        self.isRecurring = isRecurring
        self.recurringRule = recurringRule
        self.attachmentData = attachmentData
        self.transactionCurrency = transactionCurrency
        self.exchangeRate = exchangeRate
        self.parentTransactionID = parentTransactionID
        self.importSourceID = importSourceID
        self.createdAt = Date()
    }
}
