import SwiftData
import SwiftUI

struct WeeklySummaryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    private var baseCurrency: String { AppSettings.shared.baseCurrency }

    private var weekRange: (start: Date, end: Date)? {
        NotificationHelpers.previousCalendarWeek()
    }

    private var summary: ReportSummary? {
        guard let weekRange else { return nil }
        return ReportSummaryBuilder.build(
            transactions: transactions,
            from: weekRange.start,
            through: weekRange.end,
            baseCurrency: baseCurrency,
            exchangeRates: appState.resolvedExchangeRates()
        ).summary
    }

    private var topCategories: [(name: String, amount: Decimal, sharePercent: Double)] {
        guard let weekRange, let summary, summary.totalExpenses > 0 else { return [] }
        let expenses = summary.totalExpenses
        return BalanceCalculator.categorySpending(
            transactions: transactions,
            from: weekRange.start,
            through: weekRange.end,
            baseCurrency: baseCurrency,
            exchangeRates: appState.resolvedExchangeRates()
        )
        .map { name, amount in
            let ratio = (amount as NSDecimalNumber).dividing(by: expenses as NSDecimalNumber)
            let sharePercent = ratio.multiplying(by: 100).doubleValue
            return (name: name, amount: amount, sharePercent: sharePercent)
        }
        .sorted { $0.amount > $1.amount }
        .prefix(5)
        .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let summary {
                    heroCard(summary)
                    cashFlowCard(summary)
                    if !topCategories.isEmpty {
                        topCategoriesCard
                    }
                } else {
                    ContentUnavailableView(
                        "Weekly summary",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Could not determine last week’s dates.")
                    )
                    .padding(.top, 40)
                }
            }
            .padding(.vertical)
        }
        .accentTintedBackground()
        .navigationTitle("Weekly summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            await appState.refreshExchangeRates()
        }
    }

    private func heroCard(_ summary: ReportSummary) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(summary.periodLabel)
                    .font(.title3.weight(.semibold))
                Text(summary.spendingTrendLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }

    private func cashFlowCard(_ summary: ReportSummary) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Cash flow")
                    .font(.headline)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Income", systemImage: "arrow.down.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                        Text(CurrencyFormatter.format(summary.totalIncome, currencyCode: baseCurrency))
                            .font(.title3.bold().monospacedDigit())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Label("Expenses", systemImage: "arrow.up.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                        Text(CurrencyFormatter.format(summary.totalExpenses, currencyCode: baseCurrency))
                            .font(.title3.bold().monospacedDigit())
                    }
                }

                Divider()

                HStack {
                    Text("Net")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(CurrencyFormatter.format(summary.netCashFlow, currencyCode: baseCurrency))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(summary.netCashFlow >= 0 ? .green : .red)
                }

                Text("\(summary.transactionCount) transactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }

    private var topCategoriesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top spending")
                    .font(.headline)

                ForEach(Array(topCategories.enumerated()), id: \.element.name) { index, row in
                    let percent = Int(row.sharePercent.rounded())
                    HStack(spacing: 10) {
                        if let category = categories.first(where: { $0.name == row.name }) {
                            CategoryIconView(category: category, size: 28)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Text("\(index + 1)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name.localizedDisplayName)
                                .lineLimit(1)
                            Text("\(percent)% of spending")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Text(CurrencyFormatter.format(row.amount, currencyCode: baseCurrency))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}
