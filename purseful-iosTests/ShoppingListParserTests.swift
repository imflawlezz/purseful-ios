import Foundation
import Testing
@testable import purseful_ios

struct ShoppingListParserTests {
    @Test func parsesNamePriceAndQuantity() {
        let line = ShoppingListParser.parse("Milk 2.50 3")
        #expect(line.name == "Milk")
        #expect(line.price == Decimal(string: "2.50"))
        #expect(line.quantity == 3)
    }

    @Test func parsesNameAndPriceOnly() {
        let line = ShoppingListParser.parse("Bread 1.99")
        #expect(line.name == "Bread")
        #expect(line.price == Decimal(string: "1.99"))
        #expect(line.quantity == 1)
    }

    @Test func parsesNameOnly() {
        let line = ShoppingListParser.parse("Apples")
        #expect(line.name == "Apples")
        #expect(line.price == nil)
        #expect(line.quantity == 1)
    }

    @Test func parsesCommaDecimalPrice() {
        let line = ShoppingListParser.parse("Shampoo 12,99 2")
        #expect(line.name == "Shampoo")
        #expect(line.price == Decimal(string: "12.99"))
        #expect(line.quantity == 2)
    }
}
