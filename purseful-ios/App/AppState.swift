import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    var exchangeRates: [String: Decimal] = [:]
    var isLoadingRates = false
    var selectedTab: Int = 0
    var planningSection: Int = 0
    var pendingTransactionID: UUID?
    var pendingAccountID: UUID?
    var pendingCategoryID: UUID?

    func navigateToTab(_ tab: Int, planningSection: Int? = nil) {
        selectedTab = tab
        if let planningSection {
            self.planningSection = planningSection
        }
    }

    func handleSpotlightIdentifier(_ identifier: String) {
        if identifier.hasPrefix("transaction-"),
           let id = UUID(uuidString: String(identifier.dropFirst("transaction-".count))) {
            pendingTransactionID = id
            selectedTab = 1
            return
        }

        if identifier.hasPrefix("account-"),
           let id = UUID(uuidString: String(identifier.dropFirst("account-".count))) {
            pendingAccountID = id
            selectedTab = 0
            return
        }

        if identifier.hasPrefix("category-"),
           let id = UUID(uuidString: String(identifier.dropFirst("category-".count))) {
            pendingCategoryID = id
            selectedTab = 1
        }
    }

    func refreshExchangeRates() async {
        isLoadingRates = true
        defer { isLoadingRates = false }
        let base = AppSettings.shared.baseCurrency
        exchangeRates = await ExchangeRateService.shared.rates(base: base)
        ExchangeRateCache.save(exchangeRates, base: base)
    }

    func resolvedExchangeRates() -> [String: Decimal] {
        if exchangeRates.isEmpty {
            exchangeRates = ExchangeRateCache.load(for: AppSettings.shared.baseCurrency)
        }
        return exchangeRates
    }
}
