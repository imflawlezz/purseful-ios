import Foundation
import SwiftData

@Model
final class Debt {
    var id: UUID = UUID()
    var name: String = ""
    var counterparty: String = ""
    var directionRaw: String = DebtDirection.iOwe.rawValue
    var originalAmount: Decimal = 0
    var remainingAmount: Decimal = 0
    var currency: String = "USD"
    var dueDate: Date?
    var note: String = ""
    var createdAt: Date = Date()
    var createsLinkedTransactions: Bool = true

    @Relationship(deleteRule: .nullify)
    var linkedTransactions: [Transaction]?

    var direction: DebtDirection {
        get { DebtDirection(rawValue: directionRaw) ?? .iOwe }
        set { directionRaw = newValue.rawValue }
    }

    init(
        name: String,
        counterparty: String,
        direction: DebtDirection,
        originalAmount: Decimal,
        currency: String = "USD",
        dueDate: Date? = nil,
        note: String = "",
        createdAt: Date = Date(),
        createsLinkedTransactions: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.counterparty = counterparty
        self.directionRaw = direction.rawValue
        self.originalAmount = originalAmount
        self.remainingAmount = originalAmount
        self.currency = currency
        self.dueDate = dueDate
        self.note = note
        self.createdAt = createdAt
        self.createsLinkedTransactions = createsLinkedTransactions
    }
}
