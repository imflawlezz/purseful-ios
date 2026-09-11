import AppIntents
import Foundation

struct PursefulAccountEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("Account"))
    static var defaultQuery = PursefulAccountEntityQuery()

    var id: String
    var name: String
    var currency: String
    var icon: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(currency)",
            image: .init(systemName: icon)
        )
    }

    init(id: String, name: String, currency: String, icon: String) {
        self.id = id
        self.name = name
        self.currency = currency
        self.icon = icon
    }

    init(account: Account) {
        self.id = account.id.uuidString
        self.name = account.name
        self.currency = account.currency
        self.icon = account.icon
    }
}

struct PursefulAccountEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [PursefulAccountEntity.ID]) async throws -> [PursefulAccountEntity] {
        let accounts = try PursefulIntentRuntime.fetchAccounts()
        return identifiers.compactMap { id in
            accounts.first { $0.id.uuidString == id }.map(PursefulAccountEntity.init)
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [PursefulAccountEntity] {
        try PursefulIntentRuntime.fetchAccounts().map(PursefulAccountEntity.init)
    }

    @MainActor
    func defaultResult() async -> PursefulAccountEntity? {
        let accounts = try? PursefulIntentRuntime.fetchAccounts()
        let visible = AccountPreferences.visibleAccounts(accounts ?? [])
        if let defaultAccount = AppSettings.shared.defaultAccount(from: visible) {
            return PursefulAccountEntity(account: defaultAccount)
        }
        return visible.first.map(PursefulAccountEntity.init)
    }
}

extension PursefulAccountEntityQuery: EntityStringQuery {
    @MainActor
    func entities(matching string: String) async throws -> [PursefulAccountEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return try await suggestedEntities() }
        return try await suggestedEntities().filter {
            $0.name.localizedCaseInsensitiveContains(needle)
                || $0.currency.localizedCaseInsensitiveContains(needle)
        }
    }
}
