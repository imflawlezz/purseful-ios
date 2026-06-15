import Foundation

struct ShoppingListLine {
    let name: String
    let price: Decimal?
    let quantity: Int
}

enum ShoppingListParser {
    static func parse(_ line: String) -> ShoppingListLine {
        var parts = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard !parts.isEmpty else {
            return ShoppingListLine(name: "", price: nil, quantity: 1)
        }

        var quantity = 1
        if let last = parts.last, let value = Int(last), value > 0 {
            quantity = value
            parts.removeLast()
        }

        var price: Decimal?
        if let last = parts.last, let value = parseNumber(last) {
            price = value
            parts.removeLast()
        }

        let name = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = line.trimmingCharacters(in: .whitespacesAndNewlines)

        return ShoppingListLine(
            name: name.isEmpty ? fallbackName : name,
            price: price,
            quantity: quantity
        )
    }

    static func rawText(name: String, price: Decimal?, quantity: Int) -> String {
        var parts = [name.trimmingCharacters(in: .whitespacesAndNewlines)]
        if let price {
            parts.append(formatNumber(price))
        }
        if quantity != 1 {
            parts.append("\(quantity)")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func apply(_ line: ShoppingListLine, to item: ShoppingListItem) {
        item.name = line.name
        item.price = line.price
        item.quantity = max(1, line.quantity)
        item.isParsed = true
        item.rawText = rawText(name: line.name, price: line.price, quantity: line.quantity)
    }

    private static func parseNumber(_ token: String) -> Decimal? {
        let normalized = token
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return Decimal(string: normalized) ?? CurrencyFormatter.parse(normalized)
    }

    private static func formatNumber(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
