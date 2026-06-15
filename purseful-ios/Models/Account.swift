import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID = UUID()
    var name: String = ""
    var typeRaw: String = AccountType.cash.rawValue
    var currency: String = "USD"
    var initialBalance: Decimal = 0
    var colorHex: String = "#007AFF"
    var icon: String = "banknote"
    var includeInTotal: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isHidden: Bool = false
    var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.toAccount)
    var incomingTransfers: [Transaction]?

    @Relationship(deleteRule: .nullify, inverse: \PlannedPayment.account)
    var plannedPayments: [PlannedPayment]?

    @Relationship(deleteRule: .nullify, inverse: \PlannedPayment.toAccount)
    var incomingPlannedTransfers: [PlannedPayment]?

    @Relationship(deleteRule: .nullify, inverse: \Goal.linkedAccount)
    var linkedGoals: [Goal]?

    @Relationship(deleteRule: .nullify, inverse: \BankConnection.linkedAccounts)
    var bankConnections: [BankConnection]?

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .cash }
        set { typeRaw = newValue.rawValue }
    }

    var selectionLabel: String {
        "\(name) (\(currency))"
    }

    init(
        name: String,
        type: AccountType = .cash,
        currency: String = "USD",
        initialBalance: Decimal = 0,
        colorHex: String = "#007AFF",
        icon: String = "banknote",
        includeInTotal: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.currency = currency
        self.initialBalance = initialBalance
        self.colorHex = colorHex
        self.icon = icon
        self.includeInTotal = includeInTotal
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
