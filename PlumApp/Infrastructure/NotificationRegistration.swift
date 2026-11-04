import UIKit
import UserNotifications
import Supabase

final class PlumAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: "plum.deviceToken")
        Task {
            do { try await NotificationRegistration.saveToken(token); NotificationRegistration.lastRegistrationError = nil }
            catch { NotificationRegistration.report(error.localizedDescription) }
        }
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationRegistration.report("Push registration failed: \(error.localizedDescription)")
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .badge] }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let route = NotificationRoute(payload: response.notification.request.content.userInfo) else { return }
        await MainActor.run { AppNavigation.shared.open(route) }
    }
}
extension Notification.Name { static let plumPushStatus = Notification.Name("plum.pushStatus") }
@MainActor enum NotificationRegistration {
    static var lastRegistrationError: String?
    static func report(_ message: String) {
        lastRegistrationError = message
        NotificationCenter.default.post(name: .plumPushStatus, object: message)
    }
    static func request() async throws -> Bool {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.badge,.sound])
        try await synchronizePermission()
        if granted { UIApplication.shared.registerForRemoteNotifications() }
        return granted
    }
    static func synchronizePermission() async throws {
        guard let token = UserDefaults.standard.string(forKey: "plum.deviceToken"), PlumServices.client?.auth.currentSession != nil else { return }
        try await saveToken(token)
    }
    static func saveToken(_ token: String) async throws {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let status: String
        switch settings.authorizationStatus {
        case .provisional, .ephemeral: status = "provisional"
        case .authorized: status = "authorized"
        case .notDetermined: status = "not_determined"
        default: status = "denied"
        }
        struct Registration: Encodable { let token_value: String; let permission_value: String }
        _ = try await PlumAPI.client.rpc("register_device_token", params: Registration(token_value: token, permission_value: status)).execute()
    }
    static func unregister() async throws {
        guard let token = UserDefaults.standard.string(forKey: "plum.deviceToken"), let client = PlumServices.client else { return }
        _ = try await client.rpc("unregister_device_token", params: ["token_value":token]).execute()
    }
}
