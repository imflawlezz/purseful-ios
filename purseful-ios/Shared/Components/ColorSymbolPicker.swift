import SwiftUI

enum SymbolCatalog {
    static let all: [String] = [
        "banknote", "creditcard", "creditcard.fill", "building.columns", "wallet.pass",
        "cart", "cart.fill", "bag", "bag.fill", "basket", "gift", "giftcard",
        "car", "car.fill", "bus", "tram", "airplane", "fuelpump", "parkingsign",
        "house", "house.fill", "key", "bed.double", "sofa", "lightbulb", "bolt",
        "heart", "heart.fill", "pills", "cross.case", "stethoscope", "figure.run",
        "fork.knife", "cup.and.saucer", "mug", "wineglass", "takeoutbag.and.cup.and.straw",
        "film", "tv", "play.tv", "gamecontroller", "music.note", "headphones",
        "book", "books.vertical", "graduationcap", "pencil", "backpack",
        "briefcase", "laptopcomputer", "desktopcomputer", "iphone", "apple.logo",
        "chart.line.uptrend.xyaxis", "chart.bar", "dollarsign.circle", "eurosign.circle",
        "star", "star.fill", "sparkles", "flag", "tag", "bookmark",
        "person", "person.2", "pawprint", "leaf", "tree", "globe",
        "hammer", "wrench.and.screwdriver", "scissors", "paintbrush", "camera",
        "phone", "envelope", "paperplane", "bell", "calendar", "clock",
        "ellipsis.circle", "questionmark.circle", "exclamationmark.circle"
    ]
}

struct ColorPickerGrid: View {
    @Binding var selectedHex: String

    private let colors = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE",
        "#5856D6", "#FF2D55", "#00C7BE", "#8E8E93", "#FFD60A",
        "#F97316", "#EC4899", "#10B981", "#6366F1", "#06B6D4"
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
            ForEach(colors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 36, height: 36)
                    .overlay {
                        if selectedHex == hex {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.white)
                                .font(.caption.bold())
                        }
                    }
                    .onTapGesture { selectedHex = hex }
            }
        }
    }
}

struct SymbolPickerGrid: View {
    @Binding var selectedSymbol: String

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
            ForEach(SymbolCatalog.all, id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.body)
                    .frame(width: 40, height: 40)
                    .background(
                        selectedSymbol == symbol
                            ? Color.accentColor.opacity(0.18)
                            : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay {
                        if selectedSymbol == symbol {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.accentColor, lineWidth: 2)
                        }
                    }
                    .onTapGesture { selectedSymbol = symbol }
            }
        }
    }
}

struct CategoryPickerRow: View {
    let category: Category
    var depth: Int = 0

    private var tint: Color { Color(hex: category.colorHex) }

    var body: some View {
        HStack(spacing: 12) {
            if depth > 0 {
                Spacer().frame(width: CGFloat(depth) * 18)
            }
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: category.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(category.name)
                .foregroundStyle(tint)
                .font(depth == 0 ? .body.weight(.semibold) : .body)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

struct AccountPickerRow: View {
    let account: Account

    private var tint: Color { Color(hex: account.colorHex) }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: account.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(account.selectionLabel)
                    .foregroundStyle(tint)
                    .font(.body.weight(.semibold))
                Text(account.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
