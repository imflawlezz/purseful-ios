import Foundation
import SwiftData

@Model
final class RecurringRule {
    var id: UUID = UUID()
    var frequencyRaw: String = PaymentFrequency.monthly.rawValue
    var interval: Int = 1
    var startDate: Date = Date()
    var endDate: Date?
    var daysOfWeek: [Int] = []

    @Relationship(deleteRule: .nullify, inverse: \Transaction.recurringRule)
    var transactions: [Transaction]?

    @Relationship(deleteRule: .nullify, inverse: \PlannedPayment.recurringRule)
    var plannedPayments: [PlannedPayment]?

    var frequency: PaymentFrequency {
        get { PaymentFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    init(
        frequency: PaymentFrequency = .monthly,
        interval: Int = 1,
        startDate: Date = Date(),
        endDate: Date? = nil,
        daysOfWeek: [Int] = []
    ) {
        self.id = UUID()
        self.frequencyRaw = frequency.rawValue
        self.interval = interval
        self.startDate = startDate
        self.endDate = endDate
        self.daysOfWeek = daysOfWeek
    }

    func nextDate(after date: Date) -> Date? {
        let calendar = Calendar.current
        switch frequency {
        case .once:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: interval, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: interval, to: date)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2 * interval, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: interval, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: interval, to: date)
        }
    }
}
