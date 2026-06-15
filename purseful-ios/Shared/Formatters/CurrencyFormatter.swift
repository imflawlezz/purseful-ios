import Foundation

enum CurrencyFormatter {
    private static var cache: [String: NumberFormatter] = [:]

    static func locale(for currencyCode: String) -> Locale {
        switch currencyCode.uppercased() {
        case "PLN": Locale(identifier: "pl_PL")
        case "EUR": Locale(identifier: "de_DE")
        case "GBP": Locale(identifier: "en_GB")
        case "USD": Locale(identifier: "en_US")
        case "CHF": Locale(identifier: "de_CH")
        case "JPY": Locale(identifier: "ja_JP")
        default: Locale.current
        }
    }

    private static func formatter(for currencyCode: String) -> NumberFormatter {
        if let cached = cache[currencyCode] { return cached }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale(for: currencyCode)
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        cache[currencyCode] = formatter
        return formatter
    }

    static func format(_ amount: Decimal, currencyCode: String) -> String {
        formatter(for: currencyCode).string(from: amount as NSDecimalNumber) ?? "\(amount) \(currencyCode)"
    }

    static func formatCompact(_ amount: Decimal, currencyCode: String) -> String {
        let doubleValue = NSDecimalNumber(decimal: amount).doubleValue
        if abs(doubleValue) >= 1_000_000 {
            return format(Decimal(doubleValue / 1_000_000), currencyCode: currencyCode) + "M"
        }
        if abs(doubleValue) >= 1_000 {
            return format(Decimal(doubleValue / 1_000), currencyCode: currencyCode) + "K"
        }
        return format(amount, currencyCode: currencyCode)
    }

    static func parse(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")

        if let value = Decimal(string: normalized.replacingOccurrences(of: ",", with: ".")) {
            return value
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        if let number = formatter.number(from: normalized) {
            return number.decimalValue
        }

        let plFormatter = NumberFormatter()
        plFormatter.numberStyle = .decimal
        plFormatter.locale = Locale(identifier: "pl_PL")
        if let number = plFormatter.number(from: normalized) {
            return number.decimalValue
        }

        return nil
    }
}

enum DateFormatters {
    static let dayHeader: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let short: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    static let reportRange: Date.FormatStyle = .dateTime
        .day()
        .month(.abbreviated)
        .year()

    static func reportRangeString(from date: Date) -> String {
        date.formatted(reportRange)
    }
}
