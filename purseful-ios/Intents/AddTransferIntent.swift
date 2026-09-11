import AppIntents
import Foundation

struct AddTransferIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Transfer"
    static var description = IntentDescription(
        LocalizedStringResource(
            "Move money between Purseful accounts. You’ll be asked for any value that isn’t set in the shortcut."
        )
    )
    static var openAppWhenRun = false
    static var isDiscoverable = true

    @Parameter(
        title: LocalizedStringResource("From account"),
        description: LocalizedStringResource("Account money leaves"),
        requestValueDialog: IntentDialog(LocalizedStringResource("Transfer from which account?"))
    )
    var fromAccount: PursefulAccountEntity?

    @Parameter(
        title: LocalizedStringResource("To Account"),
        description: LocalizedStringResource("Account money goes to"),
        requestValueDialog: IntentDialog(LocalizedStringResource("Transfer to which account?"))
    )
    var toAccount: PursefulAccountEntity?

    @Parameter(
        title: LocalizedStringResource("Amount"),
        description: LocalizedStringResource("How much to transfer"),
        requestValueDialog: IntentDialog(LocalizedStringResource("How much do you want to transfer?"))
    )
    var amount: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Transfer \(\.$amount) from \(\.$fromAccount) to \(\.$toAccount)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let fromAccount, let fromAccountID = UUID(uuidString: fromAccount.id) else {
            throw TransactionUseCase.QuickTransactionError.noAccount
        }
        guard let toAccount, let toAccountID = UUID(uuidString: toAccount.id) else {
            throw TransactionUseCase.QuickTransactionError.noAccount
        }

        let decimalAmount = Decimal(amount)
        let transaction = try PursefulIntentRuntime.transactions().addQuickTransfer(
            amount: decimalAmount,
            fromAccountID: fromAccountID,
            toAccountID: toAccountID
        )

        let currency = transaction.account?.currency ?? AppSettings.shared.baseCurrency
        let formatted = CurrencyFormatter.format(decimalAmount, currencyCode: currency)
        let message = String(
            format: String(localized: "Transferred %@ from %@ to %@"),
            formatted,
            fromAccount.name,
            toAccount.name
        )
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
