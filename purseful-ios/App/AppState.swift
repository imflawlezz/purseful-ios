import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    var exchangeRates: [String: Decimal]
    var isLoadingRates = false
    var selectedTab: Int = 0
    var planningSection: Int = 0
    var pendingTransactionID: UUID?
    var pendingAccountID: UUID?
    var pendingCategoryID: UUID?
    var showWeeklySummary = false
    private(set) var tabScrollTokens: [Int: Int] = [:]
    private var lastTabScrollRequest: Date?
    private var startupCompletedAt: Date?
    private var lastRatesRefreshAt: Date?

    init() {
        exchangeRates = ExchangeRateCache.load(for: AppSettings.shared.baseCurrency)
    }

    /// Skip a second full foreground sync immediately after cold-start deferred work.
    var shouldSkipRedundantForegroundSync: Bool {
        guard let startupCompletedAt else { return false }
        return Date().timeIntervalSince(startupCompletedAt) < 2.5
    }

    func markStartupCompleted() {
        startupCompletedAt = Date()
    }

    func presentWeeklySummary() {
        showWeeklySummary = true
    }

    func selectTab(_ tab: Int) {
        selectedTab = tab
    }

    func requestScrollToTop(for tab: Int) {
        guard tab == selectedTab else { return }
        let now = Date()
        if let lastTabScrollRequest, now.timeIntervalSince(lastTabScrollRequest) < 0.15 {
            return
        }
        lastTabScrollRequest = now
        tabScrollTokens[tab, default: 0] += 1
    }

    func tabScrollToken(for tab: Int) -> Int {
        tabScrollTokens[tab, default: 0]
    }

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

    func refreshExchangeRates(force: Bool = false) async {
        if !force,
           let lastRatesRefreshAt,
           Date().timeIntervalSince(lastRatesRefreshAt) < 30,
           !exchangeRates.isEmpty {
            return
        }
        isLoadingRates = true
        defer { isLoadingRates = false }
        let base = AppSettings.shared.baseCurrency
        exchangeRates = await ExchangeRateService.shared.rates(base: base)
        ExchangeRateCache.save(exchangeRates, base: base)
        lastRatesRefreshAt = Date()
    }

    func resolvedExchangeRates() -> [String: Decimal] {
        if exchangeRates.isEmpty {
            exchangeRates = ExchangeRateCache.load(for: AppSettings.shared.baseCurrency)
        }
        return exchangeRates
    }
}
