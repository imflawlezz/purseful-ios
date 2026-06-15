import Foundation
import SwiftData

@Model
final class ShoppingListItem {
    var id: UUID = UUID()
    var sortOrder: Int = 0
    var name: String = ""
    var price: Decimal?
    var quantity: Int = 1
    var isChecked: Bool = false
    var isParsed: Bool = false
    var rawText: String = ""
    var createdAt: Date = Date()

    init(
        name: String = "",
        price: Decimal? = nil,
        quantity: Int = 1,
        isChecked: Bool = false,
        isParsed: Bool = false,
        rawText: String = "",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.price = price
        self.quantity = max(1, quantity)
        self.isChecked = isChecked
        self.isParsed = isParsed
        self.rawText = rawText
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    var lineTotal: Decimal? {
        guard isParsed, let price else { return nil }
        return price * Decimal(quantity)
    }
}
