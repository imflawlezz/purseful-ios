import SwiftData
import SwiftUI

struct BudgetsView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState
    @Query(sort: \Budget.name) private var budgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showAddBudget = false
    @State private var selectedBudget: Budget?

    var body: some View {
        NavigationStack {
            Group {
                if budgets.isEmpty {
                    EmptyStateView(
                        title: "No Budgets",
                        systemImage: "chart.bar",
                        message: "Create a budget to track your spending."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(budgets) { budget in
                                Button {
                                    selectedBudget = budget
                                } label: {
                                    BudgetCardView(
                                        budget: budget,
                                        transactions: transactions,
                                        exchangeRates: appState.resolvedExchangeRates()
                                    )
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                                .rowContextMenu(preview: {
                                    BudgetDetailPreviewView(
                                        budget: budget,
                                        transactions: transactions,
                                        exchangeRates: appState.resolvedExchangeRates()
                                    )
                                }, actions: [
                                    RowAction(id: "edit", title: "Edit", systemImage: "pencil") {
                                        selectedBudget = budget
                                    },
                                    RowAction(id: "delete", title: "Delete", systemImage: "trash", role: .destructive) {
                                        deleteBudget(budget)
                                    }
                                ])
                            }
                        }
                        .padding()
                    }
                }
            }
            .accentTintedBackground()
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarIcon.add { showAddBudget = true }
                }
            }
            .accentSheet(isPresented: $showAddBudget) {
                BudgetFormView()
            }
            .accentSheet(item: $selectedBudget) { budget in
                BudgetDetailView(budget: budget)
            }
        }
    }

    private func deleteBudget(_ budget: Budget) {
        try? dependencies.budgets.delete(budget)
        Haptics.light()
    }
}

struct BudgetCardView: View {
    let budget: Budget
    let transactions: [Transaction]
    let exchangeRates: [String: Decimal]

    private var baseCurrency: String { AppSettings.shared.baseCurrency }

    private var spent: Decimal {
        BudgetService.spentAmount(
            budget: budget,
            transactions: transactions,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )
    }

    private var limit: Decimal {
        BudgetService.effectiveLimit(budget: budget)
    }

    private var progress: Double {
        BudgetService.progress(spent: spent, limit: limit)
    }

    private var remaining: Decimal {
        max(0, limit - spent)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if let category = budget.category {
                        CategoryIconView(category: category, size: 20)
                    }
                    Text(budget.name)
                        .font(.headline)
                        .foregroundStyle(budget.category.map { Color(hex: $0.colorHex) } ?? Color.primary)
                    Spacer()
                    Text(budget.period.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(CurrencyFormatter.format(remaining, currencyCode: AppSettings.shared.baseCurrency))
                        .font(.title.bold())
                    Text("remaining")
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: min(progress, 1))
                    .tint(Color(hex: BudgetService.progressColor(progress: progress, threshold: budget.alertThreshold)))

                HStack {
                    Text("Spent \(CurrencyFormatter.format(spent, currencyCode: AppSettings.shared.baseCurrency))")
                    Spacer()
                    Text("Limit \(CurrencyFormatter.format(limit, currencyCode: AppSettings.shared.baseCurrency))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if budget.rollover, budget.rolloverAmount > 0 {
                    Text("Includes \(CurrencyFormatter.format(budget.rolloverAmount, currencyCode: AppSettings.shared.baseCurrency)) rolled over")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct BudgetFormView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    var budget: Budget?

    @State private var name = ""
    @State private var amountText = ""
    @State private var period: BudgetPeriod = .monthly
    @State private var selectedCategory: Category?
    @State private var rollover = false
    @State private var alertThreshold = 0.8
    @State private var customStart = Date()
    @State private var customEnd = Date()

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && CurrencyFormatter.parse(amountText) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    LabeledAmountField(label: "Budget Amount", amount: $amountText, currencyCode: AppSettings.shared.baseCurrency)
                    Picker("Period", selection: $period) {
                        ForEach(BudgetPeriod.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    if period == .custom {
                        DatePicker("Start", selection: $customStart, displayedComponents: .date)
                        DatePicker("End", selection: $customEnd, displayedComponents: .date)
                    }
                    Picker("Category", selection: $selectedCategory) {
                        Text("All Spending").tag(Optional<Category>.none)
                        ForEach(Category.userSelectable(categories, type: .expense)) { category in
                            CategoryNameLabel.picker(category: category).tag(Optional(category))
                        }
                    }
                    Toggle("Rollover Unused", isOn: $rollover)
                    VStack(alignment: .leading) {
                        Text("Alert at \(Int(alertThreshold * 100))%")
                        Slider(value: $alertThreshold, in: 0.5...1.0, step: 0.05)
                    }
                }
                .accentListRows()
            }
            .dismissKeyboardOnTap()
            .navigationTitle(budget == nil ? "New Budget" : "Edit Budget")
            .accentTintedBackground()
            .toolbar {
                FormLeadingToolbar(
                    onCancel: { dismiss() },
                    showDelete: budget != nil,
                    onDelete: budget == nil ? nil : { deleteBudget() },
                    onSave: { save() },
                    saveDisabled: !canSave
                )
            }
            .onAppear {
                guard let budget else { return }
                name = budget.name
                amountText = "\(budget.amount)"
                period = budget.period
                selectedCategory = budget.category
                rollover = budget.rollover
                alertThreshold = budget.alertThreshold
                customStart = budget.customStartDate ?? Date()
                customEnd = budget.customEndDate ?? Date()
            }
        }
    }

    private func save() {
        guard let amount = CurrencyFormatter.parse(amountText) else { return }
        let target = budget ?? Budget(name: name, amount: amount)
        target.name = name
        target.amount = amount
        target.period = period
        target.category = selectedCategory
        target.rollover = rollover
        target.alertThreshold = alertThreshold
        target.customStartDate = period == .custom ? customStart : nil
        target.customEndDate = period == .custom ? customEnd : nil
        try? dependencies.budgets.save(target, isNew: budget == nil)
        dismiss()
    }

    private func deleteBudget() {
        guard let budget else { return }
        try? dependencies.budgets.delete(budget)
        Haptics.light()
        dismiss()
    }
}

struct BudgetDetailView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable var budget: Budget
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showEdit = false

    private var baseCurrency: String { AppSettings.shared.baseCurrency }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    BudgetCardView(
                        budget: budget,
                        transactions: transactions,
                        exchangeRates: appState.resolvedExchangeRates()
                    )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(BudgetService.monthlyHistory(
                        for: budget,
                        transactions: transactions,
                        baseCurrency: baseCurrency,
                        exchangeRates: appState.resolvedExchangeRates()
                    ), id: \.label) { row in
                        HStack {
                            Text(row.label)
                            Spacer()
                            Text(CurrencyFormatter.format(row.spent, currencyCode: baseCurrency))
                        }
                    }

                    let periodTransactions = BudgetService.matchingTransactions(
                        for: budget,
                        transactions: transactions
                    )
                    if !periodTransactions.isEmpty {
                        ForEach(periodTransactions) { transaction in
                            TransactionRowView(transaction: transaction, baseCurrency: baseCurrency)
                        }
                    }
                } header: {
                    AccentListSectionHeader(title: "History")
                }
            }
            .navigationTitle(budget.name)
            .accentTintedBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarIcon.edit { showEdit = true }
                }
                DeleteLeadingToolbar {
                    try? dependencies.budgets.delete(budget)
                    dismiss()
                }
            }
            .accentSheet(isPresented: $showEdit) {
                BudgetFormView(budget: budget)
            }
        }
    }
}
