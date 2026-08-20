import UserNotifications

@MainActor
final class PursefulNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if Self.isWeeklySummary(response.notification.request) {
            appState.presentWeeklySummary()
        }
        completionHandler()
    }

    private static func isWeeklySummary(_ request: UNNotificationRequest) -> Bool {
        if request.identifier == NotificationIdentifiers.weeklySummary {
            return true
        }
        let route = request.content.userInfo[NotificationIdentifiers.routeKey] as? String
        return route == NotificationIdentifiers.weeklySummaryRoute
    }
}
