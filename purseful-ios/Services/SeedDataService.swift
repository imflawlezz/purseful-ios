import Foundation
import SwiftData

enum SeedDataService {
    struct CategorySeed {
        let name: String
        let icon: String
        let colorHex: String
        let type: CategoryType
        let children: [CategorySeed]
    }

    static let defaultCategories: [CategorySeed] = [
        CategorySeed(name: "Food", icon: "fork.knife", colorHex: "#FF9500", type: .expense, children: [
            .init(name: "Groceries", icon: "cart", colorHex: "#FF9500", type: .expense, children: []),
            .init(name: "Restaurants", icon: "cup.and.saucer", colorHex: "#FF9500", type: .expense, children: [])
        ]),
        CategorySeed(name: "Transport", icon: "car", colorHex: "#5856D6", type: .expense, children: [
            .init(name: "Fuel", icon: "fuelpump", colorHex: "#5856D6", type: .expense, children: []),
            .init(name: "Public Transit", icon: "tram", colorHex: "#5856D6", type: .expense, children: []),
            .init(name: "Parking", icon: "parkingsign", colorHex: "#5856D6", type: .expense, children: [])
        ]),
        CategorySeed(name: "Housing", icon: "house", colorHex: "#AF52DE", type: .expense, children: [
            .init(name: "Rent", icon: "key", colorHex: "#AF52DE", type: .expense, children: []),
            .init(name: "Utilities", icon: "bolt", colorHex: "#AF52DE", type: .expense, children: [])
        ]),
        CategorySeed(name: "Health", icon: "heart", colorHex: "#FF2D55", type: .expense, children: [
            .init(name: "Pharmacy", icon: "pills", colorHex: "#FF2D55", type: .expense, children: []),
            .init(name: "Doctor", icon: "stethoscope", colorHex: "#FF2D55", type: .expense, children: [])
        ]),
        CategorySeed(name: "Personal Care", icon: "scissors", colorHex: "#BF5AF2", type: .expense, children: [
            .init(name: "Haircut", icon: "scissors", colorHex: "#BF5AF2", type: .expense, children: []),
            .init(name: "Salon & Spa", icon: "sparkles", colorHex: "#BF5AF2", type: .expense, children: [])
        ]),
        CategorySeed(name: "Entertainment", icon: "film", colorHex: "#FF3B30", type: .expense, children: [
            .init(name: "Streaming", icon: "play.tv", colorHex: "#FF3B30", type: .expense, children: []),
            .init(name: "Games", icon: "gamecontroller", colorHex: "#FF3B30", type: .expense, children: [])
        ]),
        CategorySeed(name: "Shopping", icon: "bag", colorHex: "#00C7BE", type: .expense, children: [
            .init(name: "Clothing", icon: "tshirt", colorHex: "#00C7BE", type: .expense, children: []),
            .init(name: "Electronics", icon: "desktopcomputer", colorHex: "#00C7BE", type: .expense, children: [])
        ]),
        CategorySeed(name: "Gifts & Donations", icon: "gift", colorHex: "#FF6482", type: .expense, children: []),
        CategorySeed(name: "Income", icon: "arrow.down.circle", colorHex: "#34C759", type: .income, children: [
            .init(name: "Salary", icon: "briefcase", colorHex: "#34C759", type: .income, children: []),
            .init(name: "Freelance", icon: "laptopcomputer", colorHex: "#34C759", type: .income, children: []),
            .init(name: "Investments", icon: "chart.line.uptrend.xyaxis", colorHex: "#34C759", type: .income, children: []),
            .init(name: "Refunds", icon: "arrow.uturn.backward", colorHex: "#34C759", type: .income, children: []),
            .init(name: "Other Income", icon: "plus.circle", colorHex: "#34C759", type: .income, children: [])
        ]),
        CategorySeed(name: AppConstants.otherExpenseCategoryName, icon: "ellipsis.circle", colorHex: "#8E8E93", type: .expense, children: [])
    ]

    private static let additionalCategories: [CategorySeed] = [
        CategorySeed(name: "Personal Care", icon: "scissors", colorHex: "#BF5AF2", type: .expense, children: [
            .init(name: "Haircut", icon: "scissors", colorHex: "#BF5AF2", type: .expense, children: []),
            .init(name: "Salon & Spa", icon: "sparkles", colorHex: "#BF5AF2", type: .expense, children: [])
        ]),
        CategorySeed(name: "Gifts & Donations", icon: "gift", colorHex: "#FF6482", type: .expense, children: [])
    ]

    private static let retiredSystemCategoryNames: [String] = [
        "Coffee",
        "Hotels",
        "Flights",
        "Travel",
        "Courses",
        "Books",
        "Education",
        "Pets"
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext, force: Bool = false) {
        if !force && UserDefaults.standard.bool(forKey: AppConstants.hasSeededCategoriesKey) {
            ensureExpandedCategories(context: context)
            return
        }

        let descriptor = FetchDescriptor<Category>()
        let existing = (try? context.fetch(descriptor)) ?? []
        if !force && !existing.isEmpty {
            UserDefaults.standard.set(true, forKey: AppConstants.hasSeededCategoriesKey)
            ensureExpandedCategories(context: context)
            return
        }

        if force {
            existing.forEach { context.delete($0) }
        }

        var order = 0
        for seed in defaultCategories {
            insert(seed: seed, parent: nil, order: &order, context: context)
        }

        DebtService.ensureDebtCategories(context: context)

        try? context.save()
        UserDefaults.standard.set(true, forKey: AppConstants.hasSeededCategoriesKey)
    }

    @MainActor
    static func ensureSystemCategories(context: ModelContext) {
        DebtService.ensureDebtCategories(context: context)
        ensureExpandedCategories(context: context)
        try? context.save()
    }

    @MainActor
    static func ensureExpandedCategories(context: ModelContext) {
        removeRetiredCategories(context: context)

        let existing = (try? context.fetch(FetchDescriptor<Category>())) ?? []

        if let legacyOther = existing.first(where: {
            $0.name == "Other" && $0.type == .expense && $0.parent == nil && $0.isSystem
        }) {
            legacyOther.name = AppConstants.otherExpenseCategoryName
        }

        var order = (existing.map(\.sortOrder).max() ?? -1) + 1
        for seed in additionalCategories {
            ensureSeedIfMissing(seed, parent: nil, order: &order, existing: existing, context: context)
        }

        ensureIncomeChild(
            named: "Investments",
            icon: "chart.line.uptrend.xyaxis",
            parentName: "Income",
            existing: existing,
            order: &order,
            context: context
        )
        ensureIncomeChild(
            named: "Refunds",
            icon: "arrow.uturn.backward",
            parentName: "Income",
            existing: existing,
            order: &order,
            context: context
        )

        if existing.first(where: { $0.name == AppConstants.otherExpenseCategoryName && $0.type == .expense && $0.parent == nil }) == nil,
           existing.first(where: { $0.name == "Other" && $0.type == .expense && $0.parent == nil }) == nil {
            let other = Category(
                name: AppConstants.otherExpenseCategoryName,
                icon: "ellipsis.circle",
                colorHex: "#8E8E93",
                type: .expense,
                isSystem: true,
                sortOrder: order
            )
            order += 1
            context.insert(other)
        }

        try? context.save()
    }

    @MainActor
    private static func removeRetiredCategories(context: ModelContext) {
        let fallback = CategoryService.otherCategory(for: .expense, context: context)
        var existing = (try? context.fetch(FetchDescriptor<Category>())) ?? []

        for name in retiredSystemCategoryNames {
            let matches = existing.filter { $0.name == name && $0.isSystem }
            for category in matches {
                reassignReferences(from: category, to: fallback)
                context.delete(category)
            }
            existing.removeAll { $0.name == name && $0.isSystem }
        }

        try? context.save()
    }

    @MainActor
    private static func reassignReferences(from category: Category, to fallback: Category?) {
        guard let fallback else { return }

        for transaction in category.transactions ?? [] {
            transaction.category = fallback
        }
        for budget in category.budgets ?? [] {
            budget.category = fallback
        }
        for payment in category.plannedPayments ?? [] {
            payment.category = fallback
        }
    }

    @MainActor
    private static func ensureSeedIfMissing(
        _ seed: CategorySeed,
        parent: Category?,
        order: inout Int,
        existing: [Category],
        context: ModelContext
    ) {
        let match = existing.first {
            $0.name == seed.name && $0.type == seed.type && $0.parent?.id == parent?.id
        }

        let category: Category
        if let match {
            category = match
        } else {
            category = Category(
                name: seed.name,
                icon: seed.icon,
                colorHex: seed.colorHex,
                type: seed.type,
                isSystem: true,
                parent: parent,
                sortOrder: order
            )
            order += 1
            context.insert(category)
        }

        for child in seed.children {
            ensureSeedIfMissing(child, parent: category, order: &order, existing: existing, context: context)
        }
    }

    @MainActor
    private static func ensureIncomeChild(
        named name: String,
        icon: String,
        parentName: String,
        existing: [Category],
        order: inout Int,
        context: ModelContext
    ) {
        guard let parent = existing.first(where: { $0.name == parentName && $0.type == .income && $0.parent == nil }) else {
            return
        }
        guard !existing.contains(where: { $0.name == name && $0.parent?.id == parent.id }) else { return }

        let child = Category(
            name: name,
            icon: icon,
            colorHex: parent.colorHex,
            type: .income,
            isSystem: true,
            parent: parent,
            sortOrder: order
        )
        order += 1
        context.insert(child)
    }

    @MainActor
    private static func insert(seed: CategorySeed, parent: Category?, order: inout Int, context: ModelContext) {
        let category = Category(
            name: seed.name,
            icon: seed.icon,
            colorHex: seed.colorHex,
            type: seed.type,
            isSystem: true,
            parent: parent,
            sortOrder: order
        )
        order += 1
        context.insert(category)
        for child in seed.children {
            insert(seed: child, parent: category, order: &order, context: context)
        }
    }
}
