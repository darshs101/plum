import UIKit
import UserNotifications
import Supabase

final class PlumAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool { UNUserNotificationCenter.current().delegate = self; return true }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: "plum.deviceToken")
        Task { try? await NotificationRegistration.saveToken(token) }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .badge] }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let raw = response.notification.request.content.userInfo["post_id"] as? String, let id = UUID(uuidString: raw) {
            await MainActor.run { NotificationCenter.default.post(name: .plumOpenPost, object: id) }
        }
    }
}
extension Notification.Name { static let plumOpenPost = Notification.Name("plum.openPost") }
@MainActor enum NotificationRegistration {
    static func request() async throws -> Bool {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.badge,.sound])
        if granted { UIApplication.shared.registerForRemoteNotifications(); if let token = UserDefaults.standard.string(forKey: "plum.deviceToken") { try await saveToken(token) } }
        return granted
    }
    static func saveToken(_ token: String) async throws {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let status = settings.authorizationStatus == .provisional ? "provisional" : settings.authorizationStatus == .authorized ? "authorized" : "denied"
        let me = try await PlumAPI.userID()
        struct Registration: Encodable { let user_id: UUID; let token: String; let platform = "ios"; let permission_status: String; let updated_at = Date() }
        _ = try await PlumAPI.client.from("device_tokens").upsert(Registration(user_id: me, token: token, permission_status: status), onConflict: "token").execute()
    }
}
