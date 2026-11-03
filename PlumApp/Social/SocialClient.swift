import Foundation
import SwiftUI

protocol SocialClient: Sendable {
    func timeline() async throws -> [TimelineEntry]
    func profile() async throws -> ProfileSnapshot
    func notifications() async throws -> [SocialNotification]
    func setLike(postID: UUID, isLiked: Bool) async throws
}

enum SocialClientError: LocalizedError {
    case notConfigured
    case permissionDenied
    var errorDescription: String? { switch self { case .notConfigured: "Connect your Plum account to load live activity."; case .permissionDenied: "You do not have permission to view this content." } }
}

struct UnavailableSocialClient: SocialClient {
    func timeline() async throws -> [TimelineEntry] { throw SocialClientError.notConfigured }
    func profile() async throws -> ProfileSnapshot { throw SocialClientError.notConfigured }
    func notifications() async throws -> [SocialNotification] { throw SocialClientError.notConfigured }
    func setLike(postID: UUID, isLiked: Bool) async throws { throw SocialClientError.notConfigured }
}

struct TimelineEntry: Identifiable, Sendable, Hashable {
    let id: UUID; let authorName: String; let username: String; let restaurantName: String; let neighborhood: String; let dishName: String; let rating: Double; let caption: String?; let photoURL: URL?; let createdAt: Date; var likes: Int; var comments: Int; var isLiked: Bool
}

struct ProfileSnapshot: Sendable, Hashable { let displayName: String; let username: String; let city: String?; let bio: String?; let visibility: AccountVisibility; let postCount: Int; let collectionCount: Int; let followerCount: Int; let entries: [TimelineEntry]; let collections: [ProfileCollectionSummary] }
struct ProfileCollectionSummary: Identifiable, Sendable, Hashable { let id: UUID; let title: String; let itemCount: Int; let isPublic: Bool; let rank: Int? }
struct SocialNotification: Identifiable, Sendable, Hashable { enum Kind: String, Sendable { case like, comment, reply, follow, followRequest, followApproval }; let id: UUID; let kind: Kind; let title: String; let detail: String; let createdAt: Date; let isRead: Bool }

@MainActor final class SocialStore: ObservableObject {
    enum LoadState: Equatable { case idle, loading, loaded, empty, failed(String) }
    @Published private(set) var feedState: LoadState = .idle
    @Published private(set) var profileState: LoadState = .idle
    @Published private(set) var notificationState: LoadState = .idle
    @Published private(set) var entries: [TimelineEntry] = []
    @Published private(set) var profile: ProfileSnapshot?
    @Published private(set) var notifications: [SocialNotification] = []
    private let client: any SocialClient
    init(client: any SocialClient = UnavailableSocialClient()) { self.client = client }
    func loadFeed() async { feedState = .loading; do { entries = try await client.timeline().sorted { $0.createdAt > $1.createdAt }; feedState = entries.isEmpty ? .empty : .loaded } catch { feedState = .failed(error.localizedDescription) } }
    func loadProfile() async { profileState = .loading; do { profile = try await client.profile(); profileState = .loaded } catch { profileState = .failed(error.localizedDescription) } }
    func loadNotifications() async { notificationState = .loading; do { notifications = try await client.notifications(); notificationState = notifications.isEmpty ? .empty : .loaded } catch { notificationState = .failed(error.localizedDescription) } }
    func toggleLike(_ entry: TimelineEntry) async { let next = !entry.isLiked; do { try await client.setLike(postID: entry.id, isLiked: next); guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }; entries[i].isLiked = next; entries[i].likes += next ? 1 : -1 } catch { feedState = .failed(error.localizedDescription) } }
}

@MainActor final class OnboardingStore: ObservableObject {
    @AppStorage("plum.onboardingComplete") var isComplete = false
    @Published var city = "Atlanta"; @Published var neighborhood = ""; @Published var wantsToLog = false; @Published var wantsToSave = false
}
