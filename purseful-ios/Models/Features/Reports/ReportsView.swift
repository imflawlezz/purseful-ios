import Charts
import SwiftData
import SwiftUI

struct ReportsView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Transaction.date) private var transactions: [Transaction]
    @Query(filter: #Predicate<Account> { !$0.isHidden }, sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var period: ReportPeriod = .thirtyDays
    @State private var lastPresetPeriod: ReportPeriod = .thirtyDays
    @State private var customStart = Calendar.current.startOfDay(for: ReportPeriod.thirtyDays.dateRange.start)
    @State private var customEnd = Calendar.current.startOfDay(for: Date())
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var isExporting = false
    @State private var showDailySpendCategories = false

    @Bindable private var settings = AppSettings.shared

    private let chartColors: [Color] = [.blue, .green, .orange, .purple, .red, .cyan, .yellow, .mint, .indigo, .pink]

    private var baseCurrency: String { AppSettings.shared.baseCurrency }

    private var exchangeRates: [String: Decimal] {
        appState.resolvedExchangeRates()
    }

    private var dateRange: (start: Date, end: Date) {
        if period == .custom {
            return ReportPeriod.normalizedCustomRange(start: customStart, end: customEnd)
        }
        return period.dateRange
    }

    private var filteredTransactions: [Transaction] {
        transactions.filter { !$0.isSplitChild && $0.date >= dateRange.start && $0.date <= dateRange.end }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodPicker
                    categoryChart
                    cashFlowChart
                    netWorthChart
                    trendsSection
                    topPayeesSection
                    dailyAverageCard
                }
                .padding()
            }
            .accentTintedBackground()
            .navigationTitle("Reports")
            .task {
                await appState.refreshExchangeRates()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exportReportPDF()
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareURL {
                    ShareSheet(items: [shareURL])
                }
            }
            .accentSheet(isPresented: $showDailySpendCategories) {
                DailySpendCategoryPickerView()
            }
            .overlay {
                if isExporting {
                    ZStack {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                        VStack(spacing: 14) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Generating PDF…")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 22)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    private var periodRangeLabel: String {
        "\(DateFormatters.reportRangeString(from: dateRange.start)) – \(DateFormatters.reportRangeString(from: dateRange.end))"
    }

    private var periodPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Period", selection: $period) {
                ForEach(ReportPeriod.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: period) { _, new in
                if new == .custom {
                    let range = lastPresetPeriod.dateRange
                    customStart = Calendar.current.startOfDay(for: range.start)
                    customEnd = Calendar.current.startOfDay(for: range.end)
                } else {
                    lastPresetPeriod = new
                }
            }

            GlassCard {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 28, height: 28)
                        .background(.tint.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected Period")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(periodRangeLabel)
                            .font(.subheadline.weight(.semibold))
                    }

                    Spacer(minLength: 0)
                }
            }

            if period == .custom {
                GlassCard {
                    CustomDateRangeRow(start: $customStart, end: $customEnd)
                }
                .onChange(of: customStart) { _, newStart in
                    if newStart > customEnd {
                        customEnd = newStart
                    }
                }
                .onChange(of: customEnd) { _, newEnd in
                    if newEnd < customStart {
                        customStart = newEnd
                    }
                }
            }
        }
    }

    private var categorySpending: [(name: String, amount: Double)] {
        BalanceCalculator.categorySpending(
            transactions: transactions,
            from: dateRange.start,
            through: dateRange.end,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )
        .map { (name: $0.key, amount: NSDecimalNumber(decimal: $0.value).doubleValue) }
        .sorted { $0.amount > $1.amount }
    }

    private var categoryChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Spending by Category")
                    .font(.headline)
                if categorySpending.isEmpty {
                    Text("No expense data")
                        .foregroundStyle(.secondary)
                } else {
                    Chart(categorySpending, id: \.name) { item in
                        SectorMark(angle: .value("Amount", item.amount), innerRadius: .ratio(0.55))
                            .foregroundStyle(by: .value("Category", item.name))
                    }
                    .chartForegroundStyleScale(
                        domain: categorySpending.map(\.name),
                        range: categorySpending.enumerated().map { index, item in
                            categoryColor(for: item.name, fallbackIndex: index)
                        }
                    )
                    .chartLegend(.hidden)
                    .frame(height: 200)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(categorySpending.enumerated()), id: \.element.name) { index, item in
                            HStack(spacing: 8) {
                                if let category = category(named: item.name) {
                                    CategoryIconView(category: category, size: 16)
                                    Text(item.name)
                                        .foregroundStyle(Color(hex: category.colorHex))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .layoutPriority(0)
                                } else {
                                    Circle()
                                        .fill(categoryColor(for: item.name, fallbackIndex: index))
                                        .frame(width: 8, height: 8)
                                    Text(item.name)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .layoutPriority(0)
                                }
                                Spacer(minLength: 8)
                                Text(
                                    CurrencyFormatter.format(
                                        Decimal(item.amount),
                                        currencyCode: baseCurrency
                                    )
                                )
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .layoutPriority(1)
                            }
                            .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func category(named name: String) -> Category? {
        categories.first { $0.name == name }
    }

    private func categoryColor(for name: String, fallbackIndex: Int) -> Color {
        if let category = category(named: name) {
            return Color(hex: category.colorHex)
        }
        return chartColors[fallbackIndex % chartColors.count]
    }

    private var cashFlowBuckets: [(label: String, income: Double, expense: Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) {
            calendar.component(.weekOfYear, from: $0.date)
        }
        return grouped.keys.sorted().map { week in
            let items = grouped[week] ?? []
            let income = items
                .filter { $0.type == .income }
                .reduce(0.0) {
                    $0 + NSDecimalNumber(
                        decimal: BalanceCalculator.convertedAmount(
                            $1.amount,
                            for: $1,
                            baseCurrency: baseCurrency,
                            exchangeRates: exchangeRates
                        )
                    ).doubleValue
                }
            let expense = items
                .filter { $0.type == .expense }
                .reduce(0.0) {
                    $0 + NSDecimalNumber(
                        decimal: BalanceCalculator.convertedAmount(
                            $1.amount,
                            for: $1,
                            baseCurrency: baseCurrency,
                            exchangeRates: exchangeRates
                        )
                    ).doubleValue
                }
            return (label: "W\(week)", income: income, expense: expense)
        }
    }

    private var cashFlowChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cash Flow")
                    .font(.headline)
                Chart {
                    ForEach(cashFlowBuckets, id: \.label) { bucket in
                        BarMark(x: .value("Period", bucket.label), y: .value("Income", bucket.income))
                            .foregroundStyle(.green)
                        BarMark(x: .value("Period", bucket.label), y: .value("Expense", -bucket.expense))
                            .foregroundStyle(.red)
                    }
                }
                .frame(height: 200)
            }
        }
    }

    private var netWorthPoints: [(date: Date, value: Double)] {
        let calendar = Calendar.current
        var points: [(Date, Double)] = []
        var day = dateRange.start
        while day <= dateRange.end {
            let dayTransactions = transactions.filter { !$0.isSplitChild && $0.date <= day }
            let worth = BalanceCalculator.netWorth(
                accounts: accounts,
                transactions: dayTransactions,
                baseCurrency: baseCurrency,
                exchangeRates: exchangeRates
            )
            points.append((day, NSDecimalNumber(decimal: worth).doubleValue))
            day = calendar.date(byAdding: .day, value: 7, to: day) ?? dateRange.end.addingTimeInterval(1)
        }
        return points
    }

    private var netWorthChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Net Worth Trend")
                    .font(.headline)
                Chart(netWorthPoints, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Net Worth", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 180)
            }
        }
    }

    private var spendingTrend: (label: String, color: Color) {
        let calendar = Calendar.current
        let periodStart = calendar.startOfDay(for: dateRange.start)
        let periodEnd = dateRange.end
        let dayCount = max(
            1,
            (calendar.dateComponents([.day], from: periodStart, to: calendar.startOfDay(for: periodEnd)).day ?? 0) + 1
        )

        guard let previousEnd = calendar.date(byAdding: .day, value: -1, to: periodStart),
              let previousStart = calendar.date(byAdding: .day, value: -(dayCount - 1), to: previousEnd) else {
            return ("vs previous period: —", .secondary)
        }

        let current = BalanceCalculator.totalExpenses(
            transactions: transactions,
            from: periodStart,
            through: periodEnd,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )
        let previous = expenseTotal(from: previousStart, through: previousEnd)
        let delta = current - previous

        guard previous > 0 else {
            if current > 0 {
                return ("vs previous period: no prior spending", .secondary)
            }
            return ("vs previous period: 0%", .secondary)
        }

        let percent = (delta / previous) * 100
        let value = NSDecimalNumber(decimal: percent).doubleValue
        let formatted = String(format: "%+.0f%%", value)
        let color: Color = delta > 0 ? .red : (delta < 0 ? .green : .secondary)
        return ("vs previous period: \(formatted)", color)
    }

    private func expenseTotal(from start: Date, through end: Date) -> Decimal {
        BalanceCalculator.totalExpenses(
            transactions: transactions,
            from: start,
            through: end,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )
    }

    private var trendsSection: some View {
        let trend = spendingTrend

        return GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Spending Trend")
                    .font(.headline)
                Text(trend.label)
                    .foregroundStyle(trend.color)
            }
        }
    }

    private var topPayees: [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: filteredTransactions.filter { $0.type == .expense }) { $0.title }
        return grouped
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in lhs.count > rhs.count }
            .prefix(5)
            .map { $0 }
    }

    private var topPayeesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Top Payees")
                    .font(.headline)
                ForEach(topPayees, id: \.name) { payee in
                    HStack {
                        Text(payee.name.isEmpty ? "Untitled" : payee.name)
                        Spacer()
                        Text("\(payee.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var dailyAverageCard: some View {
        let average = DailySpendCalculator.dailyAverage(
            transactions: transactions,
            selectedCategoryIDs: settings.dailySpendCategoryIDs,
            lookbackDays: settings.dailySpendLookbackDays,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )
        let categorySummary = settings.dailySpendCategoryIDs.isEmpty
            ? "Choose categories such as Food or Entertainment"
            : DailySpendCalculator.selectedCategoryNames(categories, selectedIDs: settings.dailySpendCategoryIDs)
                .joined(separator: ", ")

        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Daily Discretionary Spend")
                        .font(.headline)
                    Spacer()
                    Button("Edit") {
                        showDailySpendCategories = true
                    }
                    .font(.subheadline)
                }

                Text(CurrencyFormatter.format(average, currencyCode: baseCurrency))
                    .font(.title2.bold())

                Text(categorySummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if !settings.dailySpendCategoryIDs.isEmpty {
                    Text("Based on the last \(settings.dailySpendLookbackDays) days")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func exportReportPDF() {
        guard !isExporting else { return }
        isExporting = true

        let range = dateRange
        let snapshotTransactions = transactions
        let currency = baseCurrency
        let rates = exchangeRates

        Task { @MainActor in
            await Task.yield()

            let result = ReportSummaryBuilder.build(
                transactions: snapshotTransactions,
                from: range.start,
                through: range.end,
                baseCurrency: currency,
                exchangeRates: rates
            )

            await Task.yield()

            do {
                let url = try ReportPDFExportService.export(summary: result.summary, lines: result.lines)
                shareURL = url
                showShareSheet = true
                Haptics.success()
            } catch {
                Haptics.error()
            }
            isExporting = false
        }
    }
}

private struct CustomDateRangeRow: View {
    @Binding var start: Date
    @Binding var end: Date

    private let dashColumnWidth: CGFloat = 28
    private let pickerBottomInset: CGFloat = 7

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            pickerColumn(title: "From") {
                DatePicker(
                    "From",
                    selection: $start,
                    in: ...end,
                    displayedComponents: .date
                )
            }

            Text("–")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(width: dashColumnWidth, alignment: .center)
                .padding(.bottom, pickerBottomInset)

            pickerColumn(title: "To") {
                DatePicker(
                    "To",
                    selection: $end,
                    in: start...Date(),
                    displayedComponents: .date
                )
            }
        }
    }

    private func pickerColumn<P: View>(
        title: String,
        @ViewBuilder picker: () -> P
    ) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                picker()
                    .labelsHidden()
                    .datePickerStyle(.compact)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
