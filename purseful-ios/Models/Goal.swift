import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "star.fill"
    var colorHex: String = "#34C759"
    var targetAmount: Decimal = 0
    var currentAmount: Decimal = 0
    var targetDate: Date?
    var note: String = ""
    var createdAt: Date = Date()
    var isCompleted: Bool = false

    var linkedAccount: Account?

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1, NSDecimalNumber(decimal: currentAmount / targetAmount).doubleValue)
    }

    init(
        name: String,
        targetAmount: Decimal,
        icon: String = "star.fill",
        colorHex: String = "#34C759",
        currentAmount: Decimal = 0,
        targetDate: Date? = nil,
        linkedAccount: Account? = nil,
        note: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.targetDate = targetDate
        self.linkedAccount = linkedAccount
        self.note = note
        self.createdAt = Date()
    }
}
