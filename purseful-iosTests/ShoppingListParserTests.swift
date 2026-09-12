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

    @Test func parsesQuantityBeforePrice() {
        let line = ShoppingListParser.parse("Milk 3 2.50")
        #expect(line.name == "Milk")
        #expect(line.price == Decimal(string: "2.50"))
        #expect(line.quantity == 3)
    }

    @Test func parsesLeadingQuantity() {
        let line = ShoppingListParser.parse("3 Milk 2.50")
        #expect(line.name == "Milk")
        #expect(line.price == Decimal(string: "2.50"))
        #expect(line.quantity == 3)
    }

    @Test func parsesLeadingPrice() {
        let line = ShoppingListParser.parse("2.50 Milk 3")
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

    @Test func parsesQuantityOnlyAsCount() {
        let line = ShoppingListParser.parse("Apples 3")
        #expect(line.name == "Apples")
        #expect(line.price == nil)
        #expect(line.quantity == 3)
    }

    @Test func parsesCommaDecimalPrice() {
        let line = ShoppingListParser.parse("Shampoo 12,99 2")
        #expect(line.name == "Shampoo")
        #expect(line.price == Decimal(string: "12.99"))
        #expect(line.quantity == 2)
    }

    @Test func parsesCommaPriceBeforeQuantity() {
        let line = ShoppingListParser.parse("Shampoo 2 12,99")
        #expect(line.name == "Shampoo")
        #expect(line.price == Decimal(string: "12.99"))
        #expect(line.quantity == 2)
    }

    @Test func parsesTwoWholeNumbersOrderIndependent() {
        let a = ShoppingListParser.parse("Eggs 12 2")
        #expect(a.name == "Eggs")
        #expect(a.price == Decimal(string: "12"))
        #expect(a.quantity == 2)

        let b = ShoppingListParser.parse("2 Eggs 12")
        #expect(b.name == "Eggs")
        #expect(b.price == Decimal(string: "12"))
        #expect(b.quantity == 2)
    }

    @Test func doesNotTreatWordsStartingWithEAsNumbers() {
        let line = ShoppingListParser.parse("Eggs")
        #expect(line.name == "Eggs")
        #expect(line.price == nil)
        #expect(line.quantity == 1)
    }

    @Test func parsesQuantityMarker() {
        let line = ShoppingListParser.parse("Milk x3 2.50")
        #expect(line.name == "Milk")
        #expect(line.price == Decimal(string: "2.50"))
        #expect(line.quantity == 3)
    }

    @Test func parsesTrailingQuantityMarker() {
        let line = ShoppingListParser.parse("Milk 2,50 3x")
        #expect(line.name == "Milk")
        #expect(line.price == Decimal(string: "2.50"))
        #expect(line.quantity == 3)
    }

    @Test func parsesCurrencySuffixOnPrice() {
        let line = ShoppingListParser.parse("Coffee 14,99zł 2")
        #expect(line.name == "Coffee")
        #expect(line.price == Decimal(string: "14.99"))
        #expect(line.quantity == 2)
    }

    @Test func ignoresStandaloneCurrencyToken() {
        let line = ShoppingListParser.parse("Tea 4.50 zł 3")
        #expect(line.name == "Tea")
        #expect(line.price == Decimal(string: "4.50"))
        #expect(line.quantity == 3)
    }

    @Test func parsesMultiWordName() {
        let line = ShoppingListParser.parse("Olive oil 3 24.90")
        #expect(line.name == "Olive oil")
        #expect(line.price == Decimal(string: "24.90"))
        #expect(line.quantity == 3)
    }

    @Test func applyKeepsRawTextEditableIndependentlyOfName() {
        let item = ShoppingListItem()
        ShoppingListParser.apply(ShoppingListParser.parse("Milk 2.50 3"), to: item)

        #expect(item.name == "Milk")
        #expect(item.isParsed)
        #expect(!item.rawText.isEmpty)

        item.rawText = ""
        item.isParsed = false

        #expect(item.rawText.isEmpty)
        #expect(item.name == "Milk")
    }

    @Test func applyRawTextMatchesRebuildForEdit() {
        let parsed = ShoppingListParser.parse("Olive oil 3 24.90")
        let item = ShoppingListItem()
        ShoppingListParser.apply(parsed, to: item)

        #expect(
            item.rawText
                == ShoppingListParser.rawText(name: item.name, price: item.price, quantity: item.quantity)
        )
    }

    @Test func emptyParseYieldsEmptyName() {
        let line = ShoppingListParser.parse("   ")
        #expect(line.name.isEmpty)
        #expect(line.price == nil)
        #expect(line.quantity == 1)
    }
}
