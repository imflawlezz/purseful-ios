import SwiftData
import SwiftUI

@main
struct purseful_iosApp: App {
    @State private var appState = AppState()
    @State private var dependencies: DependencyContainer
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainerProvider.makeContainer()
            _dependencies = State(initialValue: DependencyContainer(context: modelContainer.mainContext))
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
                .background(WidgetSyncObserver(dependencies: dependencies))
                .background { AccentScreenBackground() }
        }
        .modelContainer(modelContainer)
    }
}
