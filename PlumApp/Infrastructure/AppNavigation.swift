import Foundation
import Combine

struct NotificationRoute: Identifiable, Equatable, Sendable {
    enum Destination: String, Sendable { case post, profile, requests }
    let id: UUID
    let destination: Destination
    let targetID: UUID?
    let recipientID: UUID?

    init?(payload: [AnyHashable: Any]) {
        id = (payload["notification_id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
        recipientID = (payload["recipient_id"] as? String).flatMap(UUID.init(uuidString:))
        if let raw = payload["post_id"] as? String, let post = UUID(uuidString: raw) {
            destination = .post; targetID = post
        } else if payload["kind"] as? String == "follow_request" {
            destination = .requests; targetID = nil
        } else if let raw = payload["actor_id"] as? String, let actor = UUID(uuidString: raw) {
            destination = .profile; targetID = actor
        } else { return nil }
    }
}

/// Keep a cold-launch notification until authentication and optional onboarding finish.
@MainActor final class AppNavigation: ObservableObject {
    static let shared = AppNavigation()
    @Published var pendingNotification: NotificationRoute?
    func open(_ route: NotificationRoute) { pendingNotification = route }
}
