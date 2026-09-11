import AppIntents

struct PursefulShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add expense in \(.applicationName)",
                "Log expense with \(.applicationName)",
                "Add spending in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Add Expense"),
            systemImageName: "minus.circle.fill"
        )
        AppShortcut(
            intent: AddIncomeIntent(),
            phrases: [
                "Add income in \(.applicationName)",
                "Log income with \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Add Income"),
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: AddTransferIntent(),
            phrases: [
                "Transfer money in \(.applicationName)",
                "Log transfer with \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Add Transfer"),
            systemImageName: "arrow.left.arrow.right.circle.fill"
        )
    }
}
