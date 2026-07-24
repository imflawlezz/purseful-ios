import SwiftUI

enum WidgetFormatting {
    static func money(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = locale(for: currency)
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    static func locale(for currency: String) -> Locale {
        switch currency.uppercased() {
        case "PLN": Locale(identifier: "pl_PL")
        case "EUR": Locale(identifier: "de_DE")
        case "GBP": Locale(identifier: "en_GB")
        case "CHF": Locale(identifier: "de_CH")
        case "JPY": Locale(identifier: "ja_JP")
        default: Locale(identifier: "en_US")
        }
    }

    static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func shortDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

extension Color {
    init(widgetHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 59, 48)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

struct WidgetAccentBackground: View {
    let accentHex: String

    var body: some View {
        ZStack {
            Color(.systemBackground)
            Color(widgetHex: accentHex).opacity(0.12)
        }
    }
}

struct WidgetStaleLabel: View {
    var body: some View {
        Text("Open Purseful to update")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct WidgetHeroAmount: View {
    let amount: Decimal
    let currency: String
    var font: Font = .title2.bold()

    var body: some View {
        Text(WidgetFormatting.money(amount, currency: currency))
            .font(font)
            .monospacedDigit()
            .minimumScaleFactor(0.55)
            .lineLimit(1)
    }
}
