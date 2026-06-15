import Foundation
import SwiftData
import SwiftUI

enum AccountPreferences {
    static func visibleAccounts(_ accounts: [Account]) -> [Account] {
        accounts
            .filter { !$0.isHidden }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    static func preferredAccount(from accounts: [Account], matchingCurrency currency: String? = nil) -> Account? {
        let visible = visibleAccounts(accounts)
        guard !visible.isEmpty else { return nil }

        if let defaultAccount = AppSettings.shared.defaultAccount(from: visible) {
            return defaultAccount
        }

        if let currency, let match = visible.first(where: { $0.currency == currency }) {
            return match
        }

        return visible.first
    }

    @MainActor
    static func ensureSortOrders(accounts: [Account], context: ModelContext) {
        guard accounts.count > 1 else { return }

        let needsMigration = accounts.contains { $0.sortOrder == 0 }
            && Set(accounts.map(\.sortOrder)).count < accounts.count

        guard needsMigration else { return }

        let sorted = accounts.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        for (index, account) in sorted.enumerated() {
            account.sortOrder = index
        }
        try? context.save()
    }

    @MainActor
    static func nextSortOrder(accounts: [Account]) -> Int {
        (accounts.map(\.sortOrder).max() ?? -1) + 1
    }

    @MainActor
    static func moveAccounts(
        from source: IndexSet,
        to destination: Int,
        accounts: [Account],
        context: ModelContext
    ) {
        var ordered = visibleAccounts(accounts)
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, account) in ordered.enumerated() {
            account.sortOrder = index
        }
        try? context.save()
    }

    @MainActor
    static func clearDefaultIfNeeded(for account: Account) {
        if AppSettings.shared.defaultAccountID == account.id {
            AppSettings.shared.defaultAccountID = nil
        }
    }
}
