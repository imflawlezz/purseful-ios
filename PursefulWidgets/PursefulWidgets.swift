import SwiftUI
import WidgetKit

@main
struct PursefulWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AccountBalanceWidget()
        BudgetProgressWidget()
        RecentTransactionsWidget()
        TodaySpendWidget()
    }
}

struct PursefulEntry: TimelineEntry {
    let date: Date
    let accountName: String
    let accountBalance: Decimal
    let accountCurrency: String
    let budgetSpent: Decimal
    let budgetLimit: Decimal
    let todaySpend: Decimal
    let recentTransactions: [WidgetDataSync.RecentTransactionSnapshot]
}

struct PursefulProvider: TimelineProvider {
    func placeholder(in context: Context) -> PursefulEntry {
        PursefulEntry(
            date: Date(),
            accountName: "Cash",
            accountBalance: 1250,
            accountCurrency: "PLN",
            budgetSpent: 320,
            budgetLimit: 500,
            todaySpend: 42,
            recentTransactions: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PursefulEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PursefulEntry>) -> Void) {
        let entry = makeEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> PursefulEntry {
        let account = WidgetDataSync.readAccountBalance()
        let budget = WidgetDataSync.readBudgetProgress()
        return PursefulEntry(
            date: Date(),
            accountName: account.name,
            accountBalance: account.balance,
            accountCurrency: account.currency,
            budgetSpent: budget.spent,
            budgetLimit: budget.limit,
            todaySpend: WidgetDataSync.readTodaySpend(),
            recentTransactions: WidgetDataSync.readRecentTransactions()
        )
    }
}

struct AccountBalanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AccountBalanceWidget", provider: PursefulProvider()) { entry in
            AccountBalanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Account Balance")
        .description("Shows balance for your primary account.")
        .supportedFamilies([.systemSmall])
    }
}

struct AccountBalanceWidgetView: View {
    let entry: PursefulEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.accountName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(format(entry.accountBalance, entry.accountCurrency))
                .font(.title2.bold())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(URL(string: "purseful://dashboard"))
    }
}

struct BudgetProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BudgetProgressWidget", provider: PursefulProvider()) { entry in
            BudgetProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("Budget Progress")
        .description("Spending vs budget for the current month.")
        .supportedFamilies([.systemMedium])
    }
}

struct BudgetProgressWidgetView: View {
    let entry: PursefulEntry

    private var progress: Double {
        guard entry.budgetLimit > 0 else { return 0 }
        return min(1, NSDecimalNumber(decimal: entry.budgetSpent / entry.budgetLimit).doubleValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Budget")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: progress)
            Text("\(format(entry.budgetSpent, entry.accountCurrency)) spent")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(URL(string: "purseful://budgets"))
    }
}

struct RecentTransactionsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RecentTransactionsWidget", provider: PursefulProvider()) { entry in
            RecentTransactionsWidgetView(entry: entry)
        }
        .configurationDisplayName("Recent Transactions")
        .description("Your latest transactions.")
        .supportedFamilies([.systemLarge])
    }
}

struct RecentTransactionsWidgetView: View {
    let entry: PursefulEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent")
                .font(.headline)
            if entry.recentTransactions.isEmpty {
                Text("No transactions yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entry.recentTransactions.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.title)
                            .lineLimit(1)
                        Spacer()
                        Text(format(Decimal(string: item.amount) ?? 0, entry.accountCurrency))
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(URL(string: "purseful://transactions"))
    }
}

struct TodaySpendWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodaySpendWidget", provider: PursefulProvider()) { entry in
            TodaySpendWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Spend")
        .description("Total spending for today.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular])
    }
}

struct TodaySpendWidgetView: View {
    let entry: PursefulEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .accessoryInline {
                Text("Today \(format(entry.todaySpend, entry.accountCurrency))")
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(format(entry.todaySpend, entry.accountCurrency))
                        .font(.headline)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(URL(string: "purseful://transactions"))
    }
}

private func format(_ amount: Decimal, _ currency: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    formatter.locale = locale(for: currency)
    formatter.maximumFractionDigits = 2
    return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
}

private func locale(for currency: String) -> Locale {
    switch currency.uppercased() {
    case "PLN": Locale(identifier: "pl_PL")
    case "EUR": Locale(identifier: "de_DE")
    case "GBP": Locale(identifier: "en_GB")
    default: Locale(identifier: "en_US")
    }
}
