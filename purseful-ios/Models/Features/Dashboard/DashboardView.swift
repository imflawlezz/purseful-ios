import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<Account> { !$0.isHidden }, sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Budget.name) private var budgets: [Budget]
    @Query(filter: #Predicate<PlannedPayment> { $0.isActive }, sort: \PlannedPayment.nextDueDate) private var plannedPayments: [PlannedPayment]
    @Query(filter: #Predicate<Debt> { $0.remainingAmount > 0 }) private var debts: [Debt]
    @Query(filter: #Predicate<Goal> { !$0.isCompleted }) private var goals: [Goal]

    @State private var showQuickAdd = false
    @State private var showShoppingList = false
    @State private var selectedTransaction: Transaction?
    @State private var navigateToAccounts = false

    private var baseCurrency: String { AppSettings.shared.baseCurrency }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !accounts.isEmpty {
                        accountsStrip
                    }
                    netWorthCard
                    cashFlowCard
                    if !budgets.isEmpty { budgetOverview }
                    if !upcomingPayments.isEmpty { upcomingPaymentsCard }
                    if !debts.isEmpty { debtsCard }
                    if !goals.isEmpty { goalsStrip }
                    recentTransactionsCard
                }
                .padding(.vertical)
            }
            .accentTintedBackground()
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(String(localized: "Settings"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showShoppingList = true
                    } label: {
                        Image(systemName: "checklist")
                    }
                    .accessibilityLabel(String(localized: "Shopping list"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showQuickAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(String(localized: "Quick add"))
                }
            }
            .accentSheet(isPresented: $showQuickAdd) {
                NavigationStack {
                    QuickAddFlowView()
                }
            }
            .accentSheet(isPresented: $showShoppingList) {
                NavigationStack {
                    ShoppingListView()
                }
            }
            .navigationDestination(item: $selectedTransaction) { transaction in
                TransactionFormView(transaction: transaction)
            }
            .navigationDestination(isPresented: $navigateToAccounts) {
                AccountsListView()
            }
            .task {
                await appState.refreshExchangeRates()
            }
            .onChange(of: appState.pendingAccountID) { _, accountID in
                guard accountID != nil else { return }
                navigateToAccounts = true
                appState.pendingAccountID = nil
            }
            .refreshable {
                await appState.refreshExchangeRates()
                await dependencies.dashboardRefresh.refresh(
                    accounts: accounts,
                    transactions: transactions,
                    budgets: budgets,
                    exchangeRates: appState.resolvedExchangeRates()
                )
            }
        }
    }

    private var accountsStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Accounts")
                    .font(.headline)
                Spacer()
                Button("See all") { navigateToAccounts = true }
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AccountPreferences.visibleAccounts(accounts)) { account in
                        AccountBalanceCard(
                            account: account,
                            balance: BalanceCalculator.currentBalance(for: account, transactions: transactions)
                        )
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollClipDisabled()
            .contentMargins(.horizontal, 16, for: .scrollContent)
        }
    }

    private var netWorth: Decimal {
        BalanceCalculator.netWorth(
            accounts: accounts,
            transactions: transactions,
            baseCurrency: baseCurrency,
            exchangeRates: appState.resolvedExchangeRates()
        )
    }

    private var cashFlow: (income: Decimal, expense: Decimal) {
        let range = ReportPeriod.thirtyDays.dateRange
        return BalanceCalculator.cashFlow(
            transactions: transactions,
            from: range.start,
            to: range.end,
            baseCurrency: baseCurrency,
            exchangeRates: appState.resolvedExchangeRates()
        )
    }

    private func dashboardCard<Content: View>(
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            GlassCard(content: content)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    private var netWorthCard: some View {
        dashboardCard(action: { navigateToAccounts = true }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Net worth")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(netWorth, currencyCode: baseCurrency))
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                }
        }
    }

    private var cashFlowCard: some View {
        dashboardCard(action: { appState.navigateToTab(4) }) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cash flow (30 days)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    HStack {
                        VStack(alignment: .leading) {
                            Label("Income", systemImage: "arrow.down.circle.fill")
                                .foregroundStyle(.green)
                            Text(CurrencyFormatter.format(cashFlow.income, currencyCode: baseCurrency))
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Label("Expenses", systemImage: "arrow.up.circle.fill")
                                .foregroundStyle(.red)
                            Text(CurrencyFormatter.format(cashFlow.expense, currencyCode: baseCurrency))
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                        }
                    }
                }
        }
    }

    private var budgetOverview: some View {
        dashboardCard(action: { appState.navigateToTab(2) }) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Budgets")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    ForEach(budgets.prefix(3)) { budget in
                        let spent = BudgetService.spentAmount(
                            budget: budget,
                            transactions: transactions,
                            baseCurrency: baseCurrency,
                            exchangeRates: appState.resolvedExchangeRates()
                        )
                        let limit = BudgetService.effectiveLimit(budget: budget)
                        let progress = BudgetService.progress(spent: spent, limit: limit)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(budget.name.localizedDisplayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(Int(progress * 100))%")
                                    .foregroundStyle(Color(hex: BudgetService.progressColor(progress: progress, threshold: budget.alertThreshold)))
                            }
                            ProgressView(value: min(progress, 1))
                                .tint(Color(hex: BudgetService.progressColor(progress: progress, threshold: budget.alertThreshold)))
                        }
                    }
                }
        }
    }

    private var upcomingPayments: [PlannedPayment] {
        let end = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return plannedPayments.filter { $0.nextDueDate <= end }
    }

    private var upcomingPaymentsCard: some View {
        dashboardCard(action: { appState.navigateToTab(3, planningSection: 0) }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Upcoming payments")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    ForEach(upcomingPayments.prefix(5)) { payment in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(payment.name)
                                    .foregroundStyle(.primary)
                                Text(DateFormatters.short.string(from: payment.nextDueDate))
                                    .font(.caption)
                                    .foregroundStyle(payment.isOverdue ? .red : .secondary)
                            }
                            Spacer()
                            Text(CurrencyFormatter.format(payment.amount, currencyCode: payment.account?.currency ?? baseCurrency))
                                .foregroundStyle(.primary)
                        }
                    }
                }
        }
    }

    private var debtsCard: some View {
        dashboardCard(action: { appState.navigateToTab(3, planningSection: 1) }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active debts")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    ForEach(debts.prefix(3)) { debt in
                        HStack {
                            Text(debt.name)
                                .foregroundStyle(debt.direction.tintColor)
                            Spacer()
                            Text(CurrencyFormatter.format(debt.remainingAmount, currencyCode: debt.currency))
                                .foregroundStyle(debt.direction.tintColor)
                        }
                    }
                }
        }
    }

    private var goalsStrip: some View {
        dashboardCard(action: { appState.navigateToTab(3, planningSection: 2) }) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Goals")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(goals.prefix(5)) { goal in
                                DashboardGoalItem(goal: goal, currency: baseCurrency)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
        }
    }

    private var recentTransactionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recent transactions")
                        .font(.headline)
                    Spacer()
                    Button("See all") {
                        appState.navigateToTab(1)
                    }
                    .font(.subheadline)
                }
                let recent = transactions.filter { !$0.isSplitChild }.prefix(8)
                if recent.isEmpty {
                    Text("No transactions yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(recent)) { transaction in
                        Button {
                            selectedTransaction = transaction
                        } label: {
                            TransactionRowView(transaction: transaction, baseCurrency: baseCurrency)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

struct DashboardGoalItem: View {
    let goal: Goal
    let currency: String

    var body: some View {
        VStack(spacing: 8) {
            ProgressRing(progress: goal.progress, lineWidth: 5, color: Color(hex: goal.colorHex))
                .frame(width: 56, height: 56)
                .padding(6)
            Text(goal.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(Color(hex: goal.colorHex))
            Text("\(CurrencyFormatter.format(goal.currentAmount, currencyCode: currency))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            Text("of \(CurrencyFormatter.format(goal.targetAmount, currencyCode: currency))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 96)
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    let baseCurrency: String

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(category: transaction.category)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .lineLimit(1)
                    .foregroundStyle(titleColor)
                Text(DateFormatters.short.string(from: transaction.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formattedAmount)
                .font(.body.monospacedDigit())
                .foregroundStyle(amountColor)
        }
        .accessibilityElement(children: .combine)
    }

    private var displayTitle: String {
        let title = transaction.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryName = transaction.category?.name
        if title.isEmpty {
            return categoryName?.localizedDisplayName ?? String(localized: "Transaction")
        }
        if let categoryName,
           title.localizedCaseInsensitiveCompare(categoryName) == .orderedSame {
            return categoryName.localizedDisplayName
        }
        return title
    }
    private var formattedAmount: String {
        let prefix: String
        switch transaction.type {
        case .income: prefix = "+"
        case .expense: prefix = "-"
        case .transfer: prefix = ""
        }
        return prefix + CurrencyFormatter.format(
            transaction.amount,
            currencyCode: transaction.account?.currency ?? baseCurrency
        )
    }

    private var amountColor: Color {
        switch transaction.type {
        case .income: .green
        case .expense: .primary
        case .transfer: .secondary
        }
    }

    private var titleColor: Color {
        let title = transaction.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty,
           transaction.category?.name.localizedCaseInsensitiveCompare(title) != .orderedSame {
            return .primary
        }
        if let category = transaction.category { return Color(hex: category.colorHex) }
        return .primary
    }
}
