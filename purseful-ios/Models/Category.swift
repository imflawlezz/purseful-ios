import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "tag"
    var colorHex: String = "#8E8E93"
    var typeRaw: String = CategoryType.expense.rawValue
    var isSystem: Bool = false
    var isHidden: Bool = false
    var isDebtOnly: Bool = false
    var sortOrder: Int = 0

    @Relationship(deleteRule: .nullify)
    var parent: Category?

    @Relationship(deleteRule: .cascade, inverse: \Category.parent)
    var children: [Category]?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]?

    @Relationship(deleteRule: .nullify, inverse: \Budget.category)
    var budgets: [Budget]?

    @Relationship(deleteRule: .nullify, inverse: \PlannedPayment.category)
    var plannedPayments: [PlannedPayment]?

    var type: CategoryType {
        get { CategoryType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    init(
        name: String,
        icon: String = "tag",
        colorHex: String = "#8E8E93",
        type: CategoryType = .expense,
        isSystem: Bool = false,
        isHidden: Bool = false,
        isDebtOnly: Bool = false,
        parent: Category? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.typeRaw = type.rawValue
        self.isSystem = isSystem
        self.isHidden = isHidden
        self.isDebtOnly = isDebtOnly
        self.parent = parent
        self.sortOrder = sortOrder
    }

    var isUserSelectable: Bool {
        !isHidden && !isDebtOnly
    }

    static func userSelectable(_ categories: [Category], type: CategoryType? = nil) -> [Category] {
        categories.filter { category in
            guard category.isUserSelectable else { return false }
            if let type { return category.type == type }
            return true
        }
    }
}
