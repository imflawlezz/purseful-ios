import AppIntents
import Foundation

struct IncomeCategoryEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("Category"))
    static var defaultQuery = IncomeCategoryEntityQuery()

    var id: String
    var name: String
    var icon: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: .init(systemName: icon)
        )
    }

    init(id: String, name: String, icon: String) {
        self.id = id
        self.name = name
        self.icon = icon
    }

    init(category: Category) {
        self.id = category.id.uuidString
        self.name = category.name.localizedDisplayName
        self.icon = category.icon
    }
}

struct IncomeCategoryEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [IncomeCategoryEntity.ID]) async throws -> [IncomeCategoryEntity] {
        let selectable = try selectableIncomeCategories()
        return identifiers.compactMap { id in
            selectable.first { $0.id.uuidString == id }.map(IncomeCategoryEntity.init)
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [IncomeCategoryEntity] {
        try selectableIncomeCategories().map(IncomeCategoryEntity.init)
    }

    @MainActor
    func defaultResult() async -> IncomeCategoryEntity? {
        try? await suggestedEntities().first
    }

    @MainActor
    private func selectableIncomeCategories() throws -> [Category] {
        let all = try PursefulIntentRuntime.fetchCategories()
        let selectable = Category.userSelectable(all, type: .income)
        let parents = selectable.filter { $0.parent == nil }.sorted { $0.sortOrder < $1.sortOrder }
        var ordered: [Category] = []
        for parent in parents {
            ordered.append(parent)
            let children = selectable
                .filter { $0.parent?.id == parent.id }
                .sorted { $0.sortOrder < $1.sortOrder }
            ordered.append(contentsOf: children)
        }
        return ordered
    }
}

extension IncomeCategoryEntityQuery: EntityStringQuery {
    @MainActor
    func entities(matching string: String) async throws -> [IncomeCategoryEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return try await suggestedEntities() }
        return try await suggestedEntities().filter {
            $0.name.localizedCaseInsensitiveContains(needle)
        }
    }
}
