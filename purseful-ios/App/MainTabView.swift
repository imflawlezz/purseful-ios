import SwiftUI
import CoreSpotlight

/// First visit builds content; later visits keep it so scroll position survives tab switches.
private struct StickyTab<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder let content: () -> Content
    @State private var activated = false

    var body: some View {
        Group {
            if activated {
                content()
            } else {
                Color.clear
            }
        }
        .onAppear {
            if isSelected {
                activated = true
            }
        }
        .onChange(of: isSelected) { _, selected in
            if selected {
                activated = true
            }
        }
    }
}

struct MainTabView: View {
    var dependencies: DependencyContainer

    @Environment(AppState.self) private var appState
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        @Bindable var appState = appState

        // Scroll-to-top is tab-bar reselect only, not selection changes.
        TabView(selection: $appState.selectedTab) {
            StickyTab(isSelected: appState.selectedTab == 0) {
                DashboardView()
            }
            .tabItem { Label("Dashboard", systemImage: "chart.pie") }
            .tag(0)

            StickyTab(isSelected: appState.selectedTab == 1) {
                TransactionsView()
            }
            .tabItem { Label("Transactions", systemImage: "list.bullet") }
            .tag(1)

            StickyTab(isSelected: appState.selectedTab == 2) {
                BudgetsView()
            }
            .tabItem { Label("Budgets", systemImage: "chart.bar") }
            .tag(2)

            StickyTab(isSelected: appState.selectedTab == 3) {
                PlanningView()
            }
            .tabItem { Label("Planned", systemImage: "calendar") }
            .tag(3)

            StickyTab(isSelected: appState.selectedTab == 4) {
                ReportsView()
            }
            .tabItem { Label("Reports", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(4)
        }
        .background(TabBarReselectObserver { appState.requestScrollToTop(for: $0) })
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
