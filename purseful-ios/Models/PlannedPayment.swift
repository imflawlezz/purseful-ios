import Foundation
import SwiftData

@Model
final class PlannedPayment {
    var id: UUID = UUID()
    var name: String = ""
    var note: String = ""
    var amount: Decimal = 0
    var frequencyRaw: String = PaymentFrequency.monthly.rawValue
    var typeRaw: String = TransactionType.expense.rawValue
    var nextDueDate: Date = Date()
    var isActive: Bool = true
    var autoCategorize: Bool = false
    var reminderDaysBefore: Int = 1
    var lastPaidDate: Date?

    var category: Category?
    var account: Account?
    var toAccount: Account?
    var recurringRule: RecurringRule?

    var frequency: PaymentFrequency {
        get { PaymentFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        isActive && nextDueDate < Calendar.current.startOfDay(for: Date())
    }

    init(
        name: String,
        amount: Decimal,
        category: Category? = nil,
        account: Account? = nil,
        frequency: PaymentFrequency = .monthly,
        type: TransactionType = .expense,
        nextDueDate: Date = Date(),
        isActive: Bool = true,
        autoCategorize: Bool = false,
        reminderDaysBefore: Int = 1
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.category = category
        self.account = account
        self.frequencyRaw = frequency.rawValue
        self.typeRaw = type.rawValue
        self.nextDueDate = nextDueDate
        self.isActive = isActive
        self.autoCategorize = autoCategorize
        self.reminderDaysBefore = reminderDaysBefore
    }
}
