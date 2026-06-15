import Foundation
import SwiftData
import Testing
@testable import purseful_ios

@MainActor
struct DebtServiceTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Category.self, Account.self, Transaction.self, Debt.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    @Test func recordOpeningCreatesLinkedBorrowTransaction() throws {
        let context = try makeContext()
        DebtService.ensureDebtCategories(context: context)

        let account = Account(name: "Cash", type: .cash, currency: "USD", initialBalance: 1000)
        context.insert(account)

        let debt = Debt(
            name: "Credit Card",
            counterparty: "Bank",
            direction: .iOwe,
            originalAmount: 200,
            currency: "USD"
        )
        context.insert(debt)

        let transaction = DebtService.recordOpening(debt: debt, account: account, context: context)

        #expect(debt.remainingAmount == 200)
        #expect(debt.linkedTransactions?.count == 1)
        #expect(transaction?.type == .income)
        #expect(transaction?.category?.name == AppConstants.debtBorrowedCategoryName)
        #expect(transaction?.amount == 200)
    }

    @Test func recordOpeningCreatesLinkedLentTransaction() throws {
        let context = try makeContext()
        DebtService.ensureDebtCategories(context: context)

        let account = Account(name: "Cash", type: .cash, currency: "USD", initialBalance: 1000)
        context.insert(account)

        let debt = Debt(
            name: "Loan to Alex",
            counterparty: "Alex",
            direction: .theyOwe,
            originalAmount: 300,
            currency: "USD"
        )
        context.insert(debt)

        let transaction = DebtService.recordOpening(debt: debt, account: account, context: context)

        #expect(debt.remainingAmount == 300)
        #expect(transaction?.type == .expense)
        #expect(transaction?.category?.name == AppConstants.debtLentCategoryName)
    }

    @Test func recordRepaymentCreatesLinkedExpenseTransaction() throws {
        let context = try makeContext()
        DebtService.ensureDebtCategories(context: context)

        let account = Account(name: "Cash", type: .cash, currency: "USD", initialBalance: 1000)
        context.insert(account)

        let debt = Debt(
            name: "Credit Card",
            counterparty: "Bank",
            direction: .iOwe,
            originalAmount: 200,
            currency: "USD"
        )
        context.insert(debt)
        DebtService.recordOpening(debt: debt, account: account, context: context)

        let transaction = DebtService.recordRepayment(
            debt: debt,
            amount: 50,
            account: account,
            context: context
        )

        #expect(debt.remainingAmount == 150)
        #expect(debt.linkedTransactions?.count == 2)
        #expect(transaction?.type == .expense)
        #expect(transaction?.category?.name == AppConstants.debtRepaymentCategoryName)
        #expect(transaction?.amount == 50)
    }

    @Test func deletingRepaymentRestoresDebtBalance() throws {
        let context = try makeContext()
        DebtService.ensureDebtCategories(context: context)

        let account = Account(name: "Cash", type: .cash, currency: "USD", initialBalance: 1000)
        context.insert(account)

        let debt = Debt(
            name: "Credit Card",
            counterparty: "Bank",
            direction: .iOwe,
            originalAmount: 200,
            currency: "USD"
        )
        context.insert(debt)
        DebtService.recordOpening(debt: debt, account: account, context: context)

        let repayment = DebtService.recordRepayment(
            debt: debt,
            amount: 50,
            account: account,
            context: context
        )
        #expect(debt.remainingAmount == 150)

        guard let repayment else {
            Issue.record("Expected repayment transaction")
            return
        }

        DebtService.handleLinkedTransactionDeletion(repayment, context: context)
        context.delete(repayment)

        #expect(debt.remainingAmount == 200)
    }

    @Test func deletingDebtRemovesLinkedTransactions() throws {
        let context = try makeContext()
        DebtService.ensureDebtCategories(context: context)

        let account = Account(name: "Cash", type: .cash, currency: "USD", initialBalance: 1000)
        context.insert(account)

        let debt = Debt(
            name: "Credit Card",
            counterparty: "Bank",
            direction: .iOwe,
            originalAmount: 200,
            currency: "USD"
        )
        context.insert(debt)
        DebtService.recordOpening(debt: debt, account: account, context: context)
        _ = DebtService.recordRepayment(debt: debt, amount: 50, account: account, context: context)

        let linkedIDs = Set((debt.linkedTransactions ?? []).map(\.id))
        #expect(linkedIDs.count == 2)

        DebtService.deleteDebt(debt, context: context)

        let remaining = try context.fetch(FetchDescriptor<Transaction>())
        #expect(remaining.isEmpty)
    }

    @Test func recordOpeningSkipsTransactionWhenDisabled() throws {
        let context = try makeContext()
        DebtService.ensureDebtCategories(context: context)

        let account = Account(name: "Cash", type: .cash, currency: "USD", initialBalance: 1000)
        context.insert(account)

        let debt = Debt(
            name: "Informal loan",
            counterparty: "Sam",
            direction: .iOwe,
            originalAmount: 100,
            currency: "USD",
            createsLinkedTransactions: false
        )
        context.insert(debt)

        let transaction = DebtService.recordOpening(debt: debt, account: account, context: context)

        #expect(transaction == nil)
        #expect(debt.linkedTransactions?.isEmpty ?? true)
    }

    @Test func recordRepaymentWithoutLinkedTransactionUpdatesBalance() throws {
        let context = try makeContext()

        let debt = Debt(
            name: "Informal loan",
            counterparty: "Sam",
            direction: .iOwe,
            originalAmount: 100,
            currency: "USD",
            createsLinkedTransactions: false
        )
        context.insert(debt)

        let transaction = DebtService.recordRepayment(
            debt: debt,
            amount: 40,
            account: nil,
            context: context
        )

        #expect(transaction == nil)
        #expect(debt.remainingAmount == 60)
    }

    @Test func debtDueDateIncludedInNetWorthImpact() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let dueDate = calendar.date(byAdding: .day, value: 5, to: today) else { return }

        let debt = Debt(
            name: "Rent loan",
            counterparty: "Landlord",
            direction: .iOwe,
            originalAmount: 500,
            currency: "USD",
            dueDate: dueDate
        )

        let impact = DebtService.totalDebtNetWorthImpact(
            from: today,
            through: dueDate,
            debts: [debt],
            baseCurrency: "USD",
            exchangeRates: ["USD": 1]
        )

        #expect(impact == 500)
    }
}
