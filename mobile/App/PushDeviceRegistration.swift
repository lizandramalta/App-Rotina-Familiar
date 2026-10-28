import UIKit
import UserNotifications

@MainActor
final class PushDeviceRegistration: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private var registrations: [CheckedContinuation<String, any Error>] = []
    private var deviceToken: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .familyApplauseDidArrive, object: nil)
        }
        completionHandler([.banner, .sound])
    }

    func requestToken() async throws -> String? {
        if let deviceToken { return deviceToken }
        let authorized = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        guard authorized else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let shouldStart = registrations.isEmpty
            registrations.append(continuation)
            if shouldStart { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        let waiting = registrations
        registrations = []
        waiting.forEach { $0.resume(returning: token) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        let waiting = registrations
        registrations = []
        waiting.forEach { $0.resume(throwing: error) }
    }
}

extension Notification.Name {
    static let familyApplauseDidArrive = Notification.Name("familyApplauseDidArrive")
}
