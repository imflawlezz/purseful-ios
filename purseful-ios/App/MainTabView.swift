import SwiftUI
import CoreSpotlight

private struct LazyTab<Content: View>: View {
    let selectedTab: Int
    let tag: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        if selectedTab == tag {
            content()
        } else {
            Color.clear
        }
    }
}

struct MainTabView: View {
    var dependencies: DependencyContainer

    @Environment(AppState.self) private var appState
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            LazyTab(selectedTab: appState.selectedTab, tag: 0) { DashboardView() }
                .tabItem { Label("Dashboard", systemImage: "chart.pie") }
                .tag(0)

            LazyTab(selectedTab: appState.selectedTab, tag: 1) { TransactionsView() }
                .tabItem { Label("Transactions", systemImage: "list.bullet") }
                .tag(1)

            LazyTab(selectedTab: appState.selectedTab, tag: 2) { BudgetsView() }
                .tabItem { Label("Budgets", systemImage: "chart.bar") }
                .tag(2)

            LazyTab(selectedTab: appState.selectedTab, tag: 3) { PlanningView() }
                .tabItem { Label("Planned", systemImage: "calendar") }
                .tag(3)

            LazyTab(selectedTab: appState.selectedTab, tag: 4) { ReportsView() }
                .tabItem { Label("Reports", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(4)
        }
        .tint(settings.accentColor)
        .environment(dependencies)
        .accentSheet(isPresented: $appState.showWeeklySummary) {
            NavigationStack {
                WeeklySummaryView()
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
            appState.handleSpotlightIdentifier(identifier)
        }
        .task {
            await dependencies.dashboardRefresh.refreshExchangeRates(appState: appState)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == AppConstants.urlScheme else { return }
        switch url.host {
        case "dashboard": appState.selectedTab = 0
        case "transactions": appState.selectedTab = 1
        case "budgets": appState.selectedTab = 2
        case "planning": appState.selectedTab = 3
        case "reports": appState.selectedTab = 4
        case NotificationIdentifiers.weeklySummaryRoute:
            appState.presentWeeklySummary()
        default: break
        }
    }
}
