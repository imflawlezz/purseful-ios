import AppIntents
import Foundation

struct AddIncomeIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Income"
    static var description = IntentDescription(
        LocalizedStringResource(
            "Log income to a Purseful account. You’ll be asked for the amount and category when they aren’t set in the shortcut."
        )
    )
    static var openAppWhenRun = false
    static var isDiscoverable = true

    @Parameter(
        title: LocalizedStringResource("Account"),
        description: LocalizedStringResource("Account for this transaction"),
        requestValueDialog: IntentDialog(LocalizedStringResource("Which account?"))
    )
    var account: PursefulAccountEntity?

    @Parameter(
        title: LocalizedStringResource("Amount"),
        description: LocalizedStringResource("How much you received"),
        requestValueDialog: IntentDialog(LocalizedStringResource("How much did you receive?"))
    )
    var amount: Double

    @Parameter(
        title: LocalizedStringResource("Category"),
        description: LocalizedStringResource("Income category"),
        requestValueDialog: IntentDialog(LocalizedStringResource("Which category?"))
    )
    var category: IncomeCategoryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) to \(\.$category) in \(\.$account)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let categoryID = UUID(uuidString: category.id) else {
            throw TransactionUseCase.QuickTransactionError.categoryNotFound
        }

        let accountID = account.flatMap { UUID(uuidString: $0.id) }
        let decimalAmount = Decimal(amount)
        let transaction = try PursefulIntentRuntime.transactions().addQuickIncome(
            amount: decimalAmount,
            categoryID: categoryID,
            accountID: accountID
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
