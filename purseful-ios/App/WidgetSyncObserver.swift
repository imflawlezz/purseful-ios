import SwiftData
import SwiftUI

struct WidgetSyncObserver: View {
    let dependencies: DependencyContainer
    let appState: AppState

    @Environment(\.scenePhase) private var scenePhase
    @State private var syncTask: Task<Void, Never>?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    scheduleForegroundSync()
                }
            }
            .onDisappear {
                syncTask?.cancel()
            }
    }

    private func scheduleForegroundSync() {
        syncTask?.cancel()
        syncTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            performForegroundSync()
        }
    }

    private func performForegroundSync() {
        Task {
            await appState.refreshExchangeRates()
            let exchangeRates = appState.resolvedExchangeRates()
            let transactions = (try? dependencies.repository.fetch(FetchDescriptor<Transaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            ))) ?? []

            try? dependencies.budgets.processRollovers(
                transactions: transactions,
                exchangeRates: exchangeRates
            )
            dependencies.importExport.syncWidgets()

            await NotificationScheduler.syncAll(
                context: dependencies.repository.context,
                transactions: transactions,
                exchangeRates: exchangeRates
            )
        }
    }
}
