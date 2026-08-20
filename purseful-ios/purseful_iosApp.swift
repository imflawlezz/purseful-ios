import SwiftData
import SwiftUI
import UserNotifications

@main
struct purseful_iosApp: App {
    @State private var appState: AppState
    @State private var dependencies: DependencyContainer
    private let modelContainer: ModelContainer
    private let notificationDelegate: PursefulNotificationCenterDelegate

    init() {
        do {
            let state = AppState()
            modelContainer = try ModelContainerProvider.makeContainer()
            _appState = State(initialValue: state)
            _dependencies = State(initialValue: DependencyContainer(context: modelContainer.mainContext))
            let delegate = PursefulNotificationCenterDelegate(appState: state)
            notificationDelegate = delegate
            UNUserNotificationCenter.current().delegate = delegate
            AccentTheme.prepareListChrome(accent: AppSettings.shared.accentColor)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(dependencies: dependencies)
                .environment(appState)
                .environment(dependencies)
                .dismissKeyboardOnTap()
                .task(priority: .utility) {
                    await Task.yield()
                    await dependencies.appBootstrap.runStartupTasks()
                }
                .background(WidgetSyncObserver(dependencies: dependencies, appState: appState))
                .background { AccentScreenBackground() }
        }
        .modelContainer(modelContainer)
    }
}
