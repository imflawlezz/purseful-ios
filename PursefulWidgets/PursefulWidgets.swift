import AppIntents
import SwiftUI
import WidgetKit

@main
struct PursefulWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BalancesWidget()
        BudgetProgressWidget()
        RecentTransactionsWidget()
        TodaySpendLockWidget()
    }
}

// MARK: - Shared

struct PursefulSnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDataSync.Snapshot
}

enum SnapshotTimeline {
    static func entry(date: Date = Date()) -> PursefulSnapshotEntry {
        PursefulSnapshotEntry(date: date, snapshot: WidgetDataSync.loadSnapshot())
    }

    static func placeholder() -> PursefulSnapshotEntry {
        PursefulSnapshotEntry(date: Date(), snapshot: WidgetDataSync.placeholderSnapshot())
    }

    static func timeline(from entry: PursefulSnapshotEntry) -> Timeline<PursefulSnapshotEntry> {
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
            ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(next))
    }
}

struct StaticSnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> PursefulSnapshotEntry { SnapshotTimeline.placeholder() }

    func getSnapshot(in context: Context, completion: @escaping (PursefulSnapshotEntry) -> Void) {
        completion(SnapshotTimeline.entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PursefulSnapshotEntry>) -> Void) {
        completion(SnapshotTimeline.timeline(from: SnapshotTimeline.entry()))
    }
}

// MARK: - Balances

struct BalancesEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDataSync.Snapshot
    let accountID: String?
}

struct BalancesProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BalancesEntry {
        BalancesEntry(date: Date(), snapshot: WidgetDataSync.placeholderSnapshot(), accountID: nil)
    }

    func snapshot(for configuration: SelectAccountIntent, in context: Context) async -> BalancesEntry {
        makeEntry(configuration: configuration)
    }

    func timeline(for configuration: SelectAccountIntent, in context: Context) async -> Timeline<BalancesEntry> {
        let entry = makeEntry(configuration: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
            ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func makeEntry(configuration: SelectAccountIntent) -> BalancesEntry {
        BalancesEntry(
            date: Date(),
            snapshot: WidgetDataSync.loadSnapshot(),
            accountID: configuration.account?.id
        )
    }
}

struct BalancesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "BalancesWidget",
            intent: SelectAccountIntent.self,
            provider: BalancesProvider()
        ) { entry in
            BalancesWidgetView(entry: entry)
        }
        .configurationDisplayName(String(localized: "Balances"))
        .description(String(localized: "Your account balances. The larger size also shows today’s spend and what’s coming up."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BalancesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BalancesEntry

    private var layout: (primary: WidgetDataSync.AccountSnapshot?, secondary: [WidgetDataSync.AccountSnapshot]) {
        entry.snapshot.balancesLayout(primaryID: entry.accountID)
    }

    var body: some View {
        Group {
            if entry.snapshot.isStale && entry.snapshot.accounts.isEmpty {
                WidgetStaleLabel()
            } else if family == .systemSmall {
                smallBalances
            } else {
                mediumBalances
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            WidgetAccentBackground(accentHex: entry.snapshot.accentColorHex)
        }
        .widgetURL(URL(string: "purseful://dashboard"))
    }

    private var smallBalances: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let primary = layout.primary {
                primaryBalance(primary, heroFont: .title3.bold())
            }
            if !layout.secondary.isEmpty {
                Divider().opacity(0.35)
                ForEach(layout.secondary) { account in
                    secondaryBalanceRow(account)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var mediumBalances: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                if let primary = layout.primary {
                    primaryBalance(primary, heroFont: .title3.bold())
                        .layoutPriority(1)
                }
                if !layout.secondary.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(layout.secondary) { account in
                            secondaryBalanceRow(account)
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SPENT TODAY")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(WidgetFormatting.money(
                        entry.snapshot.decimal(entry.snapshot.todaySpend),
                        currency: entry.snapshot.baseCurrency
                    ))
                    .font(.title3.bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                }
                .layoutPriority(1)

                if entry.snapshot.upcomingPayments.isEmpty {
                    Text("Nothing upcoming")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("UPCOMING")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(entry.snapshot.upcomingPayments.prefix(4))) { payment in
                            upcomingPaymentRow(payment)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private func upcomingPaymentRow(_ payment: WidgetDataSync.NextPaymentSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(payment.name)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(WidgetFormatting.money(
                entry.snapshot.decimal(payment.amount),
                currency: payment.currency
            ))
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(payment.isOverdue ? .red : .primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    private func primaryBalance(
        _ account: WidgetDataSync.AccountSnapshot,
        heroFont: Font
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(account.name.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            WidgetHeroAmount(
                amount: entry.snapshot.decimal(account.balance),
                currency: account.currency,
                font: heroFont
            )
        }
    }

    private func secondaryBalanceRow(_ account: WidgetDataSync.AccountSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(account.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(WidgetFormatting.money(
                entry.snapshot.decimal(account.balance),
                currency: account.currency
            ))
            .font(.caption.monospacedDigit().weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Budget

struct BudgetProgressEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDataSync.Snapshot
    let budgetID: String?
}

struct BudgetProgressProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BudgetProgressEntry {
        BudgetProgressEntry(date: Date(), snapshot: WidgetDataSync.placeholderSnapshot(), budgetID: nil)
    }

    func snapshot(for configuration: SelectBudgetIntent, in context: Context) async -> BudgetProgressEntry {
        makeEntry(configuration: configuration)
    }

    func timeline(for configuration: SelectBudgetIntent, in context: Context) async -> Timeline<BudgetProgressEntry> {
        let entry = makeEntry(configuration: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
            ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func makeEntry(configuration: SelectBudgetIntent) -> BudgetProgressEntry {
        BudgetProgressEntry(
            date: Date(),
            snapshot: WidgetDataSync.loadSnapshot(),
            budgetID: configuration.budget?.id
        )
    }
}

struct BudgetProgressWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "BudgetProgressWidget",
            intent: SelectBudgetIntent.self,
            provider: BudgetProgressProvider()
        ) { entry in
            BudgetProgressWidgetView(entry: entry)
        }
        .configurationDisplayName(String(localized: "Budget"))
        .description(String(localized: "What’s left in a budget."))
        .supportedFamilies([.systemMedium])
    }
}

struct BudgetProgressWidgetView: View {
    let entry: BudgetProgressEntry

    private var budget: WidgetDataSync.BudgetSnapshot? {
        entry.snapshot.budget(id: entry.budgetID)
    }

    private var progress: Double {
        guard let budget else { return 0 }
        let limit = entry.snapshot.decimal(budget.limit)
        guard limit > 0 else { return 0 }
        return min(1, NSDecimalNumber(decimal: entry.snapshot.decimal(budget.spent) / limit).doubleValue)
    }

    var body: some View {
        Group {
            if entry.snapshot.isStale && entry.snapshot.budgets.isEmpty {
                WidgetStaleLabel()
            } else if let budget {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(budget.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(budget.period)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Text("Remaining")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        WidgetHeroAmount(
                            amount: entry.snapshot.decimal(budget.remaining),
                            currency: entry.snapshot.baseCurrency,
                            font: .title.bold()
                        )
                        Text(spentOfLimitLabel(for: budget))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                    ZStack {
                        Circle()
                            .stroke(Color(widgetHex: entry.snapshot.accentColorHex).opacity(0.2), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                Color(widgetHex: entry.snapshot.accentColorHex),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(.headline.monospacedDigit())
                    }
                    .frame(width: 84, height: 84)
                }
            } else {
                Text("No budgets yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            WidgetAccentBackground(accentHex: entry.snapshot.accentColorHex)
        }
        .widgetURL(URL(string: "purseful://budgets"))
    }

    private func spentOfLimitLabel(for budget: WidgetDataSync.BudgetSnapshot) -> String {
        let spent = WidgetFormatting.money(
            entry.snapshot.decimal(budget.spent),
            currency: entry.snapshot.baseCurrency
        )
        let limit = WidgetFormatting.money(
            entry.snapshot.decimal(budget.limit),
            currency: entry.snapshot.baseCurrency
        )
        return String(localized: "\(spent) of \(limit)")
    }
}

// MARK: - Recent

struct RecentTransactionsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RecentTransactionsWidget", provider: StaticSnapshotProvider()) { entry in
            RecentTransactionsWidgetView(entry: entry)
        }
        .configurationDisplayName(String(localized: "Recent transactions"))
        .description(String(localized: "Latest activity."))
        .supportedFamilies([.systemLarge])
    }
}

struct RecentTransactionsWidgetView: View {
    let entry: PursefulSnapshotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent")
                    .font(.headline)
                Spacer()
                Text("Spent today \(WidgetFormatting.money(entry.snapshot.decimal(entry.snapshot.todaySpend), currency: entry.snapshot.baseCurrency))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if entry.snapshot.isStale && entry.snapshot.recentTransactions.isEmpty {
                WidgetStaleLabel()
            } else if entry.snapshot.recentTransactions.isEmpty {
                Text("No transactions yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entry.snapshot.recentTransactions.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(widgetHex: item.categoryColorHex))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(WidgetFormatting.relativeDate(item.date))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 8)
                        Text(signedAmount(item))
                            .font(.subheadline.monospacedDigit().weight(.medium))
                            .foregroundStyle(amountColor(item.type))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            Spacer(minLength: 0)

            if let payment = entry.snapshot.nextPayment {
                Divider().opacity(0.35)
                HStack {
                    Text(payment.isOverdue ? "Overdue" : "Next")
                        .font(.caption2)
                        .foregroundStyle(payment.isOverdue ? .red : .secondary)
                    Text(payment.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(WidgetFormatting.money(
                        entry.snapshot.decimal(payment.amount),
                        currency: payment.currency
                    ))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(WidgetFormatting.shortDueDate(payment.dueDate))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            WidgetAccentBackground(accentHex: entry.snapshot.accentColorHex)
        }
        .widgetURL(URL(string: "purseful://transactions"))
    }

    private func signedAmount(_ item: WidgetDataSync.RecentTransactionSnapshot) -> String {
        let value = entry.snapshot.decimal(item.amount)
        let formatted = WidgetFormatting.money(value, currency: entry.snapshot.baseCurrency)
        switch item.type {
        case "income":
            return "+\(formatted)"
        case "expense":
            return "−\(formatted)"
        default:
            return formatted
        }
    }

    private func amountColor(_ type: String) -> Color {
        switch type {
        case "income": .green
        case "expense": .primary
        default: .secondary
        }
    }
}

// MARK: - Lock screen

struct TodaySpendLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodaySpendWidget", provider: StaticSnapshotProvider()) { entry in
            TodaySpendLockWidgetView(entry: entry)
        }
        .configurationDisplayName(String(localized: "Today’s spend"))
        .description(String(localized: "Today’s spending on the Lock Screen."))
        .supportedFamilies([.accessoryInline, .accessoryRectangular])
    }
}

struct TodaySpendLockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PursefulSnapshotEntry

    private var amount: Decimal { entry.snapshot.decimal(entry.snapshot.todaySpend) }
    private var currency: String { entry.snapshot.baseCurrency }

    var body: some View {
        Group {
            if family == .accessoryInline {
                Text("Spent \(WidgetFormatting.money(amount, currency: currency))")
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spent today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(WidgetFormatting.money(amount, currency: currency))
                        .font(.headline.monospacedDigit())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    if let payment = entry.snapshot.nextPayment {
                        Text("\(WidgetFormatting.money(entry.snapshot.decimal(payment.amount), currency: payment.currency)) · \(WidgetFormatting.shortDueDate(payment.dueDate))")
                            .font(.caption2)
                            .foregroundStyle(payment.isOverdue ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(URL(string: "purseful://transactions"))
    }
}
