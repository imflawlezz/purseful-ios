import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class DependencyContainer {
    let repository: DataRepositoryProtocol

    let appBootstrap: AppBootstrapUseCase
    let transactions: TransactionUseCase
    let budgets: BudgetUseCase
    let plannedPayments: PlannedPaymentUseCase
    let debts: DebtUseCase
    let goals: GoalUseCase
    let categories: CategoryUseCase
    let accounts: AccountUseCase
    let importExport: ImportExportUseCase
    let dashboardRefresh: DashboardRefreshUseCase
    let shoppingList: ShoppingListUseCase

    init(context: ModelContext) {
        let repository = SwiftDataRepository(context: context)
        let budgets = BudgetUseCase(repository: repository)
        self.repository = repository
        self.budgets = budgets
        self.appBootstrap = AppBootstrapUseCase(repository: repository, budgets: budgets)
        self.transactions = TransactionUseCase(repository: repository)
        self.plannedPayments = PlannedPaymentUseCase(repository: repository)
        self.debts = DebtUseCase(repository: repository)
        self.goals = GoalUseCase(repository: repository)
        self.categories = CategoryUseCase(repository: repository)
        self.accounts = AccountUseCase(repository: repository)
        self.importExport = ImportExportUseCase(repository: repository)
        self.dashboardRefresh = DashboardRefreshUseCase(repository: repository, budgets: budgets)
        self.shoppingList = ShoppingListUseCase(repository: repository)
    }
}
