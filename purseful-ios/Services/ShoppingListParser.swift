import Foundation

struct ShoppingListLine {
    let name: String
    let price: Decimal?
    let quantity: Int
}

enum ShoppingListParser {
    private static let currencyTokens: Set<String> = [
        "zł", "zl", "pln", "eur", "usd", "gbp", "chf", "jpy", "uah", "czk", "nok", "sek", "dkk"
    ]

    static func parse(_ line: String) -> ShoppingListLine {
        let tokens = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard !tokens.isEmpty else {
            return ShoppingListLine(name: "", price: nil, quantity: 1)
        }

        var nameParts: [String] = []
        var fractions: [Decimal] = []
        var wholes: [Int] = []
        var markedQuantity: Int?

        for token in tokens {
            if let quantity = parseQuantityMarker(token) {
                markedQuantity = quantity
                continue
            }

            if isCurrencyToken(token) {
                continue
            }

            if let number = parseNumericToken(token) {
                if number.isFractional {
                    fractions.append(number.value)
                } else if let whole = number.wholeValue, whole > 0 {
                    wholes.append(whole)
                }
                continue
            }

            nameParts.append(token)
        }

        let name = nameParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let (price, quantity) = classify(fractions: fractions, wholes: wholes, markedQuantity: markedQuantity)

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

    /// Fractional tokens are prices; whole numbers are quantities / whole prices.
    private static func classify(
        fractions: [Decimal],
        wholes: [Int],
        markedQuantity: Int?
    ) -> (price: Decimal?, quantity: Int) {
        let priceFromFraction = fractions.first

        if let marked = markedQuantity {
            let quantity = max(1, marked)
            if let priceFromFraction {
                return (priceFromFraction, quantity)
            }
            if let wholePrice = wholes.max() {
                return (Decimal(wholePrice), quantity)
            }
            return (nil, quantity)
        }

        if let priceFromFraction {
            let quantity = wholes.last.map { max(1, $0) } ?? 1
            return (priceFromFraction, quantity)
        }

        switch wholes.count {
        case 0:
            return (nil, 1)
        case 1:
            // Single whole number → quantity ("Apples 3")
            return (nil, max(1, wholes[0]))
        default:
            // Two+ whole numbers, no fractional price:
            // smaller → quantity, larger → unit price (order-independent).
            let sorted = wholes.sorted()
            return (Decimal(sorted.last!), max(1, sorted[0]))
        }
    }

    private static func parseQuantityMarker(_ token: String) -> Int? {
        let lowered = token.lowercased()
        let patterns = [
            #"^[x×\*]\s*(\d+)$"#,
            #"^(\d+)\s*[x×\*]$"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: lowered),
                  let value = Int(lowered[range]),
                  value > 0 else {
                continue
            }
            return value
        }
        return nil
    }

    private static func isCurrencyToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 1, "$€£¥₴".contains(trimmed) {
            return true
        }
        return currencyTokens.contains(trimmed.lowercased())
    }

    private static func parseNumericToken(_ token: String) -> (value: Decimal, isFractional: Bool, wholeValue: Int?)? {
        var raw = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        while let first = raw.first, "$€£¥₴".contains(first) {
            raw.removeFirst()
        }
        while let last = raw.last, "$€£¥₴".contains(last) {
            raw.removeLast()
        }

        let lowered = raw.lowercased()
        for suffix in currencyTokens.sorted(by: { $0.count > $1.count }) {
            if lowered.hasSuffix(suffix) {
                raw = String(raw.dropLast(suffix.count))
                break
            }
        }

        raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, isNumericLiteral(raw) else { return nil }

        let hasFractionSeparator = raw.contains(".") || raw.contains(",")
        guard let value = parseNumber(raw) else { return nil }

        let wholeValue: Int?
        if !hasFractionSeparator {
            let intValue = NSDecimalNumber(decimal: value).intValue
            if intValue > 0, Decimal(intValue) == value {
                wholeValue = intValue
            } else {
                wholeValue = nil
            }
        } else {
            wholeValue = nil
        }

        return (value, hasFractionSeparator, wholeValue)
    }

    /// Rejects `Decimal(string:)` scientific-notation traps like `"Eggs"` → `0`.
    private static func isNumericLiteral(_ raw: String) -> Bool {
        raw.range(of: #"^[+-]?\d+([.,]\d+)?$"#, options: .regularExpression) != nil
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
