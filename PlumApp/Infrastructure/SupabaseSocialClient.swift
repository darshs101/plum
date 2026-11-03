import Foundation
import Supabase

actor SupabaseSocialClient: SocialClient {
    private let client: SupabaseClient
    init(configuration: SupabaseConfiguration) { client = SupabaseClient(supabaseURL: configuration.url, supabaseKey: configuration.publishableKey) }

    func timeline() async throws -> [TimelineEntry] {
        let user = try await client.auth.user()
        let follows: [FollowRow] = try await client.from("follows").select("following_id").eq("follower_id", value: user.id).eq("status", value: "approved").execute().value
        guard !follows.isEmpty else { return [] }
        let rows: [FeedRow] = try await client.from("posts").select("id,caption,created_at,profiles!posts_author_id_fkey(display_name,username),restaurants!posts_restaurant_id_fkey(name,neighborhood),post_dishes(rating,dishes(name)),post_photos(storage_path)").in("author_id", values: follows.map(\.followingID)).order("created_at", ascending: false).limit(50).execute().value
        return rows.compactMap { row in
            guard let dish = row.postDishes.first?.dishes?.name, let rating = row.postDishes.first?.rating else { return nil }
            return TimelineEntry(id: row.id, authorName: row.profiles.displayName, username: row.profiles.username, restaurantName: row.restaurants.name, neighborhood: row.restaurants.neighborhood ?? "Atlanta", dishName: dish, rating: rating, caption: row.caption, photoURL: nil, createdAt: row.createdAt, likes: 0, comments: 0, isLiked: false)
        }
    }
    func profile() async throws -> ProfileSnapshot {
        let user = try await client.auth.user()
        let profile: ProfileRow = try await client.from("profiles").select("display_name,username,visibility,city").eq("id", value: user.id).single().execute().value
        let collections: [CollectionRow] = try await client.from("collections").select("id,title,is_public,kind").eq("owner_id", value: user.id).execute().value
        return ProfileSnapshot(displayName: profile.displayName, username: profile.username, city: profile.city, bio: nil, visibility: AccountVisibility(rawValue: profile.visibility) ?? .public, postCount: 0, collectionCount: collections.count, followerCount: 0, entries: [], collections: collections.map { .init(id: $0.id, title: $0.title, itemCount: 0, isPublic: $0.isPublic, rank: $0.kind == "ranked" ? 1 : nil) })
    }
    func notifications() async throws -> [SocialNotification] {
        let rows: [NotificationRow] = try await client.from("notifications").select("id,kind,created_at,read_at").order("created_at", ascending: false).limit(50).execute().value
        return rows.compactMap { row in guard let kind = SocialNotification.Kind(rawValue: row.kind.camelizedNotificationKind) else { return nil }; return .init(id: row.id, kind: kind, title: row.kind.replacingOccurrences(of: "_", with: " ").capitalized, detail: "New Plum activity", createdAt: row.createdAt, isRead: row.readAt != nil) }
    }
    func setLike(postID: UUID, isLiked: Bool) async throws { let user = try await client.auth.user(); if isLiked { _ = try await client.from("likes").insert(["post_id": postID.uuidString, "user_id": user.id.uuidString]).execute() } else { _ = try await client.from("likes").delete().eq("post_id", value: postID).eq("user_id", value: user.id).execute() } }
}

extension PlumServices { static let social: any SocialClient = { guard let configuration = try? SupabaseConfiguration.load() else { return UnavailableSocialClient() }; return SupabaseSocialClient(configuration: configuration) }() }
private struct FollowRow: Decodable { let followingID: UUID; enum CodingKeys: String, CodingKey { case followingID = "following_id" } }
private struct FeedRow: Decodable { let id: UUID; let caption: String?; let createdAt: Date; let profiles: FeedProfile; let restaurants: FeedRestaurant; let postDishes: [FeedDish]; enum CodingKeys: String, CodingKey { case id, caption, profiles, restaurants; case createdAt = "created_at"; case postDishes = "post_dishes" } }
private struct FeedProfile: Decodable { let displayName, username: String; enum CodingKeys: String, CodingKey { case username; case displayName = "display_name" } }
private struct FeedRestaurant: Decodable { let name: String; let neighborhood: String? }
private struct FeedDish: Decodable { let rating: Double; let dishes: DishName? }
private struct DishName: Decodable { let name: String }
private struct ProfileRow: Decodable { let displayName, username, visibility: String; let city: String?; enum CodingKeys: String, CodingKey { case username, visibility, city; case displayName = "display_name" } }
private struct CollectionRow: Decodable { let id: UUID; let title, kind: String; let isPublic: Bool; enum CodingKeys: String, CodingKey { case id,title,kind; case isPublic = "is_public" } }
private struct NotificationRow: Decodable { let id: UUID; let kind: String; let createdAt: Date; let readAt: Date?; enum CodingKeys: String, CodingKey { case id,kind; case createdAt = "created_at"; case readAt = "read_at" } }
private extension String { var camelizedNotificationKind: String { split(separator: "_").enumerated().map { $0.offset == 0 ? String($0.element) : String($0.element).capitalized }.joined() } }
