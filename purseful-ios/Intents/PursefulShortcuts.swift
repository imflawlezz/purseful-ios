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
    }
}
