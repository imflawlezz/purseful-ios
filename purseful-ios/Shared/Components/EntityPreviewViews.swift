import SwiftData
import SwiftUI

struct EntityPreviewContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(16)
        }
        .frame(maxWidth: 340, maxHeight: 460)
    }
}

struct PreviewSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.clear)
                    .glassEffect(in: .rect(cornerRadius: 12))
            }
        }
    }
}

struct PreviewLabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

struct BudgetDetailPreviewView: View {
    let budget: Budget
    let transactions: [Transaction]
    let exchangeRates: [String: Decimal]

    private var baseCurrency: String { AppSettings.shared.baseCurrency }

    private var historyRows: [(label: String, spent: Decimal)] {
        BudgetService.monthlyHistory(
            for: budget,
            transactions: transactions,
            baseCurrency: baseCurrency,
            exchangeRates: exchangeRates
        )
    }

    private var periodTransactions: [Transaction] {
        BudgetService.matchingTransactions(for: budget, transactions: transactions)
    }

    var body: some View {
        EntityPreviewContainer {
            BudgetCardView(
                budget: budget,
                transactions: transactions,
                exchangeRates: exchangeRates
            )

            PreviewSection(title: "History") {
                ForEach(historyRows, id: \.label) { row in
                    PreviewLabeledRow(
                        label: row.label,
                        value: CurrencyFormatter.format(row.spent, currencyCode: baseCurrency)
                    )
                }

                if periodTransactions.isEmpty {
                    Text("No matching transactions this period")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Divider()
                    ForEach(periodTransactions) { transaction in
                        TransactionRowView(transaction: transaction, baseCurrency: baseCurrency)
                    }
                }
            }
        }
    }
}

struct DebtDetailPreviewView: View {
    let debt: Debt

    private var openingDateLabel: String {
        debt.direction == .iOwe ? "Borrowed On" : "Lent On"
    }

    private var openingDate: Date {
        DebtService.openingTransaction(for: debt)?.date ?? debt.createdAt
    }

    private var linkedTransactions: [Transaction] {
        (debt.linkedTransactions ?? []).sorted { $0.date > $1.date }
    }

    var body: some View {
        EntityPreviewContainer {
            PreviewSection(title: debt.name) {
                PreviewLabeledRow(
                    label: "Counterparty",
                    value: debt.counterparty.isEmpty ? "—" : debt.counterparty
                )
                PreviewLabeledRow(
                    label: "Remaining",
                    value: CurrencyFormatter.format(debt.remainingAmount, currencyCode: debt.currency)
                )
                PreviewLabeledRow(
                    label: "Original",
                    value: CurrencyFormatter.format(debt.originalAmount, currencyCode: debt.currency)
                )
                PreviewLabeledRow(label: "Direction", value: debt.direction.displayName)
                PreviewLabeledRow(
                    label: openingDateLabel,
                    value: DateFormatters.short.string(from: openingDate)
                )
                if let dueDate = debt.dueDate {
                    PreviewLabeledRow(
                        label: "Due Date",
                        value: DateFormatters.short.string(from: dueDate)
                    )
                }
                if !debt.note.isEmpty {
                    PreviewLabeledRow(label: "Note", value: debt.note)
                }
                PreviewLabeledRow(
                    label: "Linked transactions",
                    value: debt.createsLinkedTransactions ? "On" : "Off"
                )
            }

            PreviewSection(title: "Linked Transactions") {
                if linkedTransactions.isEmpty {
                    Text("No linked transactions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(linkedTransactions) { transaction in
                        TransactionRowView(transaction: transaction, baseCurrency: debt.currency)
                    }
                }
            }
        }
    }
}

struct GoalDetailPreviewView: View {
    let goal: Goal

    private var baseCurrency: String { AppSettings.shared.baseCurrency }

    private var estimatedCompletion: String? {
        guard !goal.isCompleted, goal.currentAmount > 0, goal.targetAmount > goal.currentAmount else { return nil }
        let remaining = goal.targetAmount - goal.currentAmount
        let daysSinceCreation = max(1, Calendar.current.dateComponents([.day], from: goal.createdAt, to: Date()).day ?? 1)
        let dailyRate = goal.currentAmount / Decimal(daysSinceCreation)
        guard dailyRate > 0 else { return nil }
        let daysLeft = NSDecimalNumber(decimal: remaining / dailyRate).intValue
        guard let date = Calendar.current.date(byAdding: .day, value: daysLeft, to: Date()) else { return nil }
        return DateFormatters.short.string(from: date)
    }

    var body: some View {
        EntityPreviewContainer {
            PreviewSection(title: goal.name) {
                HStack {
                    Spacer()
                    GoalProgressIndicator(
                        progress: goal.progress,
                        colorHex: goal.colorHex,
                        isCompleted: goal.isCompleted,
                        lineWidth: 8,
                        size: 96
                    )
                    Spacer()
                }

                PreviewLabeledRow(
                    label: "Current",
                    value: CurrencyFormatter.format(goal.currentAmount, currencyCode: baseCurrency)
                )
                PreviewLabeledRow(
                    label: "Target",
                    value: CurrencyFormatter.format(goal.targetAmount, currencyCode: baseCurrency)
                )
                if let targetDate = goal.targetDate {
                    PreviewLabeledRow(
                        label: "Target Date",
                        value: DateFormatters.short.string(from: targetDate)
                    )
                }
                if !goal.note.isEmpty {
                    PreviewLabeledRow(label: "Note", value: goal.note)
                }
                if let estimatedCompletion {
                    PreviewLabeledRow(label: "Estimated completion", value: estimatedCompletion)
                }
                if goal.isCompleted {
                    Label("Goal completed", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct PlannedPaymentPreviewView: View {
    let payment: PlannedPayment
    var completed = false

    private var baseCurrency: String { AppSettings.shared.baseCurrency }

    var body: some View {
        EntityPreviewContainer {
            PreviewSection(title: payment.name) {
                PreviewLabeledRow(label: "Type", value: payment.type.displayName)
                PreviewLabeledRow(
                    label: "Amount",
                    value: CurrencyFormatter.format(
                        payment.amount,
                        currencyCode: payment.account?.currency ?? baseCurrency
                    )
                )
                PreviewLabeledRow(label: "Frequency", value: payment.frequency.displayName)
                if completed, let lastPaidDate = payment.lastPaidDate {
                    PreviewLabeledRow(
                        label: "Paid",
                        value: DateFormatters.short.string(from: lastPaidDate)
                    )
                } else {
                    PreviewLabeledRow(
                        label: "Next Due",
                        value: DateFormatters.short.string(from: payment.nextDueDate)
                    )
                }
                PreviewLabeledRow(
                    label: "Account",
                    value: payment.account?.selectionLabel ?? "—"
                )
                if payment.type == .transfer {
                    PreviewLabeledRow(
                        label: "To Account",
                        value: payment.toAccount?.selectionLabel ?? "—"
                    )
                } else {
                    PreviewLabeledRow(
                        label: "Category",
                        value: payment.category?.name ?? "None"
                    )
                }
                PreviewLabeledRow(label: "Active", value: payment.isActive ? "Yes" : "No")
                PreviewLabeledRow(
                    label: "Auto-create",
                    value: payment.autoCategorize ? "Yes" : "No"
                )
                PreviewLabeledRow(
                    label: "Reminder",
                    value: "\(payment.reminderDaysBefore) day(s) before"
                )
                if !payment.note.isEmpty {
                    PreviewLabeledRow(label: "Note", value: payment.note)
                }
            }
        }
    }
}

struct TransactionDetailPreviewView: View {
    let transaction: Transaction

    private var baseCurrency: String { AppSettings.shared.baseCurrency }

    var body: some View {
        EntityPreviewContainer {
            PreviewSection(title: transaction.title.isEmpty ? "Transaction" : transaction.title) {
                PreviewLabeledRow(label: "Type", value: transaction.type.displayName)
                PreviewLabeledRow(
                    label: "Amount",
                    value: CurrencyFormatter.format(
                        transaction.amount,
                        currencyCode: transaction.account?.currency ?? baseCurrency
                    )
                )
                PreviewLabeledRow(
                    label: "Date",
                    value: DateFormatters.short.string(from: transaction.date)
                )
                PreviewLabeledRow(
                    label: "Account",
                    value: transaction.account?.selectionLabel ?? "—"
                )
                if transaction.type == .transfer {
                    PreviewLabeledRow(
                        label: "To Account",
                        value: transaction.toAccount?.selectionLabel ?? "—"
                    )
                } else {
                    PreviewLabeledRow(
                        label: "Category",
                        value: transaction.category?.name ?? "—"
                    )
                }
                if !transaction.note.isEmpty {
                    PreviewLabeledRow(label: "Note", value: transaction.note)
                }
            }
        }
    }
}

struct AccountDetailPreviewView: View {
    let account: Account
    let balance: Decimal

    var body: some View {
        EntityPreviewContainer {
            PreviewSection(title: account.selectionLabel) {
                HStack(spacing: 12) {
                    AccountIconView(account: account, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.type.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.format(balance, currencyCode: account.currency))
                            .font(.title2.bold())
                    }
                }

                PreviewLabeledRow(label: "Currency", value: account.currency)
                PreviewLabeledRow(
                    label: "Initial Balance",
                    value: CurrencyFormatter.format(account.initialBalance, currencyCode: account.currency)
                )
                PreviewLabeledRow(
                    label: "Include in Net Worth",
                    value: account.includeInTotal ? "Yes" : "No"
                )
            }
        }
    }
}

struct CategoryDetailPreviewView: View {
    let category: Category

    var body: some View {
        EntityPreviewContainer {
            PreviewSection(title: category.name) {
                HStack(spacing: 12) {
                    CategoryIconView(category: category, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.type == .income ? "Income" : "Expense")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if category.isSystem {
                            Text("System category")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let parent = category.parent {
                    PreviewLabeledRow(label: "Parent", value: parent.name)
                }
                PreviewLabeledRow(label: "Hidden", value: category.isHidden ? "Yes" : "No")
            }
        }
    }
}
