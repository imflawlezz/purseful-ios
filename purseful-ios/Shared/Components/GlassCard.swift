import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(in: .rect(cornerRadius: 16))
            .contentShape(.rect(cornerRadius: 16))
    }
}

struct AccountBalanceCard: View {
    let account: Account
    let balance: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                AccountIconView(account: account, size: 28)
                Text(account.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            Text(CurrencyFormatter.format(balance, currencyCode: account.currency))
                .font(.title3.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(account.type.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 160, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.clear)
                .glassEffect(in: .rect(cornerRadius: 14))
        }
        .contentShape(.rect(cornerRadius: 14))
    }
}

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 12
    var color: Color = .accentColor

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring, value: progress)
        }
        .padding(lineWidth / 2)
    }
}

struct CurrencyAmountInput: View {
    @Binding var amount: String
    let currencyCode: String

    var body: some View {
        TextField("0.00", text: $amount)
            .keyboardType(.decimalPad)
            .font(.title2.monospacedDigit())
            .multilineTextAlignment(.trailing)
            .padding(.leading, 44)
            .overlay(alignment: .leading) {
                Text(currencyCode)
                    .foregroundStyle(.secondary)
            }
    }
}

struct AmountField: View {
    @Binding var amount: String
    let currencyCode: String

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            CurrencyAmountInput(amount: $amount, currencyCode: currencyCode)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

struct LabeledAmountField: View {
    let label: String
    @Binding var amount: String
    let currencyCode: String

    var body: some View {
        HStack {
            Text(label)
            Spacer(minLength: 12)
            CurrencyAmountInput(amount: $amount, currencyCode: currencyCode)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

struct GoalProgressIndicator: View {
    let progress: Double
    let colorHex: String
    let isCompleted: Bool
    var lineWidth: CGFloat = 6
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: size * 0.82))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: isCompleted)
                    .transition(.scale.combined(with: .opacity))
            } else {
                ProgressRing(progress: progress, lineWidth: lineWidth, color: Color(hex: colorHex))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isCompleted)
    }
}

struct CategoryIconView: View {
    let category: Category?
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: category?.colorHex ?? "#8E8E93").opacity(0.2))
                .frame(width: size, height: size)
            Image(systemName: category?.icon ?? "tag")
                .font(.system(size: size * 0.4))
                .foregroundStyle(Color(hex: category?.colorHex ?? "#8E8E93"))
        }
        .accessibilityLabel(category?.name ?? "Category")
    }
}

struct CategoryNameLabel: View {
    let category: Category?
    var placeholder: String = "Select"
    var iconSize: CGFloat = 24
    var spacing: CGFloat = 8
    var font: Font = .body

    var body: some View {
        HStack(spacing: spacing) {
            CategoryIconView(category: category, size: iconSize)
            Text(category?.name ?? placeholder)
                .font(font)
                .foregroundStyle(category.map { Color(hex: $0.colorHex) } ?? Color.secondary)
        }
    }

    /// Extra spacing for SwiftUI `Picker` rows, where the default layout compresses icon and title.
    static func picker(
        category: Category?,
        placeholder: String = "Select",
        iconSize: CGFloat = 24,
        font: Font = .body
    ) -> CategoryNameLabel {
        CategoryNameLabel(
            category: category,
            placeholder: placeholder,
            iconSize: iconSize,
            spacing: 16,
            font: font
        )
    }
}

struct AccountIconView: View {
    let account: Account?
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: account?.colorHex ?? "#007AFF").opacity(0.2))
                .frame(width: size, height: size)
            Image(systemName: account?.icon ?? "banknote")
                .font(.system(size: size * 0.4))
                .foregroundStyle(Color(hex: account?.colorHex ?? "#007AFF"))
        }
        .accessibilityLabel(account?.name ?? "Account")
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
    }
}
