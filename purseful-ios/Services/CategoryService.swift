import Foundation
import SwiftData

enum CategoryService {
    @MainActor
    static func otherCategory(for type: CategoryType, context: ModelContext) -> Category? {
        let name = type == .income
            ? AppConstants.otherIncomeCategoryName
            : AppConstants.otherExpenseCategoryName
        return category(named: name, type: type, context: context)
    }

    @MainActor
    static func resolvedCategory(
        _ category: Category?,
        for transactionType: TransactionType,
        context: ModelContext
    ) -> Category? {
        switch transactionType {
        case .transfer:
            return nil
        case .income:
            return resolvedCategory(category, for: CategoryType.income, context: context)
        case .expense:
            return resolvedCategory(category, for: CategoryType.expense, context: context)
        }
    }

    @MainActor
    static func resolvedCategory(
        _ category: Category?,
        for type: CategoryType,
        context: ModelContext
    ) -> Category? {
        if let category { return category }
        return otherCategory(for: type, context: context)
    }

    @MainActor
    private static func category(named name: String, type: CategoryType, context: ModelContext) -> Category? {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate {
            $0.name == name && $0.typeRaw == typeRaw
        })
        return try? context.fetch(descriptor).first
    }
}
