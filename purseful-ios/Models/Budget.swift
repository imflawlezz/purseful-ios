import Foundation
import SwiftData

@Model
final class Budget {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Decimal = 0
    var periodRaw: String = BudgetPeriod.monthly.rawValue
    var customStartDate: Date?
    var customEndDate: Date?
    var rollover: Bool = false
    var alertThreshold: Double = 0.8
    var createdAt: Date = Date()
    var rolloverAmount: Decimal = 0
    var rolloverPeriodStart: Date?

    var category: Category?

    var period: BudgetPeriod {
        get { BudgetPeriod(rawValue: periodRaw) ?? .monthly }
        set { periodRaw = newValue.rawValue }
    }

    init(
        name: String,
        amount: Decimal,
        period: BudgetPeriod = .monthly,
        category: Category? = nil,
        rollover: Bool = false,
        alertThreshold: Double = 0.8,
        customStartDate: Date? = nil,
        customEndDate: Date? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.periodRaw = period.rawValue
        self.category = category
        self.rollover = rollover
        self.alertThreshold = alertThreshold
        self.customStartDate = customStartDate
        self.customEndDate = customEndDate
        self.createdAt = Date()
    }
}
