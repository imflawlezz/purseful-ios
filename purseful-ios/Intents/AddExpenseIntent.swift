import AppIntents
import Foundation

struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense"
    static var description = IntentDescription(
        LocalizedStringResource(
            "Log an expense to your default Purseful account. You’ll be asked for the amount and category."
        )
    )
    static var openAppWhenRun = false
    static var isDiscoverable = true

    @Parameter(
        title: LocalizedStringResource("Amount"),
        description: LocalizedStringResource("How much you spent"),
        requestValueDialog: IntentDialog(LocalizedStringResource("How much did you spend?"))
    )
    var amount: Double

    @Parameter(
        title: LocalizedStringResource("Category"),
        description: LocalizedStringResource("Expense category"),
        requestValueDialog: IntentDialog(LocalizedStringResource("Which category?"))
    )
    var category: ExpenseCategoryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) to \(\.$category)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let categoryID = UUID(uuidString: category.id) else {
            throw TransactionUseCase.QuickExpenseError.categoryNotFound
        }

        let decimalAmount = Decimal(amount)
        let transaction = try PursefulIntentRuntime.transactions().addQuickExpense(
            amount: decimalAmount,
            categoryID: categoryID
        )

        let currency = transaction.account?.currency ?? AppSettings.shared.baseCurrency
        let formatted = CurrencyFormatter.format(decimalAmount, currencyCode: currency)
        let message = String(
            format: String(localized: "Added %@ to %@"),
            formatted,
            category.name
        )
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
