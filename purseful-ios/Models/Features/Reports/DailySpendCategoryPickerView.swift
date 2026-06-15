import SwiftData
import SwiftUI

struct DailySpendCategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Bindable private var settings = AppSettings.shared

    private var expenseGroups: [Category] {
        categories.filter { $0.type == .expense && !$0.isHidden && $0.parent == nil }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Trend window") {
                    Picker("Lookback", selection: $settings.dailySpendLookbackDays) {
                        ForEach(DailySpendLookback.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }
                }

                if expenseGroups.isEmpty {
                    Section("Categories") {
                        Text("No expense categories available")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(expenseGroups) { group in
                        let children = expenseChildren(of: group)
                        if group.isUserSelectable || !children.isEmpty {
                            Section(group.name) {
                                if group.isUserSelectable {
                                    categoryRow(group)
                                }
                                ForEach(children) { child in
                                    categoryRow(child)
                                        .padding(.leading, 8)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Daily Spend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    ToolbarIcon.done { dismiss() }
                }
            }
        }
    }

    private func expenseChildren(of parent: Category) -> [Category] {
        (parent.children ?? [])
            .filter { $0.isUserSelectable && $0.type == .expense && !$0.isHidden }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private func categoryRow(_ category: Category) -> some View {
        HStack {
            CategoryNameLabel(category: category)
            Spacer(minLength: 0)
            if settings.dailySpendCategoryIDs.contains(category.id) {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            toggle(category.id)
        }
    }

    private func toggle(_ id: UUID) {
        if settings.dailySpendCategoryIDs.contains(id) {
            settings.dailySpendCategoryIDs.remove(id)
        } else {
            settings.dailySpendCategoryIDs.insert(id)
        }
    }
}

struct NetWorthProjectionBreakdown {
    let current: Decimal
    let plannedImpact: Decimal
    let debtImpact: Decimal
    let variableSpend: Decimal
    let projected: Decimal
    let dailyAverage: Decimal
    let variableDayCount: Int
    let categorySummary: String
}

enum NetWorthProjectionCalculator {
    @MainActor
    static func breakdown(
        selectedDay: Date,
        accounts: [Account],
        transactions: [Transaction],
        plannedPayments: [PlannedPayment],
        debts: [Debt],
        categories: [Category],
        baseCurrency: String,
        exchangeRates: [String: Decimal],
        calendar: Calendar = .current
    ) -> NetWorthProjectionBreakdown {
        let settings = AppSettings.shared
        let today = calendar.startOfDay(for: Date())
        let current = BalanceCalculator.netWorth(
            accounts: accounts,
            transactions: transactions,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )

        let selectedCategoryIDs = settings.dailySpendCategoryIDs
        let dailyAverage = DailySpendCalculator.dailyAverage(
            transactions: transactions,
            selectedCategoryIDs: selectedCategoryIDs,
            lookbackDays: settings.dailySpendLookbackDays,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates,
            calendar: calendar
        )

        let categorySummary: String
        if selectedCategoryIDs.isEmpty {
            categorySummary = "No daily spend categories selected"
        } else {
            categorySummary = DailySpendCalculator.selectedCategoryNames(categories, selectedIDs: selectedCategoryIDs)
                .joined(separator: ", ")
        }

        guard calendar.startOfDay(for: selectedDay) >= today else {
            return NetWorthProjectionBreakdown(
                current: current,
                plannedImpact: 0,
                debtImpact: 0,
                variableSpend: 0,
                projected: current,
                dailyAverage: dailyAverage,
                variableDayCount: 0,
                categorySummary: categorySummary
            )
        }

        let plannedImpact = PlannedPaymentSchedule.totalPlannedNetWorthImpact(
            from: today,
            through: selectedDay,
            payments: plannedPayments,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates,
            calendar: calendar
        )

        let debtImpact = DebtService.totalDebtNetWorthImpact(
            from: today,
            through: selectedDay,
            debts: debts,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates,
            calendar: calendar
        )

        let variableDayCount = max(
            0,
            calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: selectedDay)).day ?? 0
        )
        let variableSpend = DailySpendCalculator.projectedVariableSpend(
            dailyAverage: dailyAverage,
            from: today,
            through: selectedDay,
            calendar: calendar
        )

        return NetWorthProjectionBreakdown(
            current: current,
            plannedImpact: plannedImpact,
            debtImpact: debtImpact,
            variableSpend: variableSpend,
            projected: current - plannedImpact - debtImpact - variableSpend,
            dailyAverage: dailyAverage,
            variableDayCount: variableDayCount,
            categorySummary: categorySummary
        )
    }
}
