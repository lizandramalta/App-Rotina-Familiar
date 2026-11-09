import UIKit
import UserNotifications

@MainActor
final class PushDeviceRegistration: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private var registrations: [CheckedContinuation<String, any Error>] = []
    private var deviceToken: String?
    /// TEL-052 opened from a recognition notification (SPEC-020 · SCRUM-103).
    let recognitionRouter = RecognitionNotificationRouter()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let isRecognition = WeeklyRecognitionNotification.recognitionID(from: notification.request.content.userInfo) != nil
        Task { @MainActor in
            NotificationCenter.default.post(
                name: isRecognition ? .weeklyRecognitionDidArrive : .familyApplauseDidArrive,
                object: nil
            )
        }
        completionHandler([.banner, .sound])
    }

    /// Tapping a recognition notification queues TEL-052; it opens only after a valid session revalidates it.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let recognitionID = WeeklyRecognitionNotification.recognitionID(from: response.notification.request.content.userInfo)
        if let recognitionID {
            Task { @MainActor in recognitionRouter.receive(recognitionID) }
        }
        completionHandler()
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
    static let weeklyRecognitionDidArrive = Notification.Name("weeklyRecognitionDidArrive")
}
