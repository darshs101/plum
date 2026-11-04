import Foundation
import Supabase

struct LiveProfile: Codable, Identifiable, Sendable {
    let id: UUID
    var username: String
    var display_name: String
    var visibility: String
    var city: String?
    var neighborhood: String?
    var avatar_path: String?
}
struct LiveDish: Codable, Identifiable, Sendable { let id: UUID; let name: String; let restaurant_id: UUID }
struct LiveRating: Codable, Identifiable, Sendable { let id: UUID; let dish_id: UUID; var rating: Double; let dishes: DishLabel?; struct DishLabel: Codable, Sendable { let name: String } }
struct LivePhoto: Codable, Identifiable, Sendable { let id: UUID; let storage_path: String; let position: Int; var url: URL? }
struct LivePost: Codable, Identifiable, Sendable {
    let id: UUID; let author_id: UUID; let restaurant_id: UUID; var caption: String?; let visit_date: String?; let created_at: Date
    let profiles: LiveProfile?; let restaurants: PlaceLabel?; var post_dishes: [LiveRating]; var post_photos: [LivePhoto]
    struct PlaceLabel: Codable, Sendable { let name: String; let neighborhood: String? }
    var displayDate: Date {
        visit_date.flatMap { PostCalendarDate.date(from: $0) } ?? created_at
    }
}
struct LiveCollection: Codable, Identifiable, Sendable { let id: UUID; let owner_id: UUID; var title: String; var kind: String; var is_public: Bool }
struct LiveCollectionItem: Codable, Identifiable, Sendable {
    let id: UUID; let restaurant_id: UUID?; let post_id: UUID?; var rank: Int?
    let restaurants: PlaceName?; var posts: SavedPost?
    struct PlaceName: Codable, Sendable { let name: String }
    struct SavedPost: Codable, Sendable { let restaurants: PlaceName?; let post_dishes: [LiveRating] }
    var restaurantName: String { restaurants?.name ?? posts?.restaurants?.name ?? "Unavailable tasting" }
}
struct LiveComment: Codable, Identifiable, Sendable { let id: UUID; let author_id: UUID; let body: String; let parent_id: UUID?; let created_at: Date; let profiles: Name?; struct Name: Codable, Sendable { let username: String } }
struct LiveFollow: Codable, Sendable { let follower_id: UUID; let following_id: UUID; let status: String; var created_at: Date? }
struct LiveInboxFriend: Decodable, Identifiable, Sendable { let id: UUID; let username: String; let display_name: String; let avatar_path: String?; let last_message: String?; let last_message_at: Date?; let followed_at: Date }
struct LiveNotification: Codable, Identifiable, Sendable { let id: UUID; let kind: String; let actor_id: UUID?; let post_id: UUID?; let created_at: Date; let read_at: Date? }
struct LiveConversation: Codable, Identifiable, Sendable { let id: UUID; let direct_key: String }
struct LiveMessage: Codable, Identifiable, Sendable { let id: UUID; let sender_id: UUID; let body: String?; let created_at: Date; let post_shares: SharedPost?; struct SharedPost: Codable, Sendable { let post_id: UUID } }

enum PlumAPI {
    static var client: SupabaseClient { get throws { guard let client = PlumServices.client else { throw SocialClientError.notConfigured }; return client } }
    static func userID() async throws -> UUID { try await client.auth.session.user.id }
    static func profile(_ id: UUID) async throws -> LiveProfile {
        let rows: [LiveProfile] = try await client.rpc("profile_identity", params: ["subject":id.uuidString]).execute().value
        guard var profile = rows.first else { throw SocialClientError.permissionDenied }; struct Avatar: Decodable { let avatar_path: String? }; let avatar: [Avatar] = try await client.from("profiles").select("avatar_path").eq("id", value: id).execute().value; profile.avatar_path = avatar.first?.avatar_path; return profile
    }
    static let postSelection = "*,profiles!posts_author_id_fkey(id,username,display_name,visibility,city,neighborhood,avatar_path),restaurants!posts_restaurant_id_fkey(name,neighborhood),post_dishes(id,dish_id,rating,dishes(name)),post_photos(id,storage_path,position)"
    static func hydrate(_ rows: [LivePost]) async throws -> [LivePost] {
        var rows = rows
        for i in rows.indices {
            rows[i].post_photos.sort { $0.position < $1.position }
            for j in rows[i].post_photos.indices { rows[i].post_photos[j].url = try? await client.storage.from("post-media").createSignedURL(path: rows[i].post_photos[j].storage_path, expiresIn: 300) }
        }
        return rows
    }
    static func posts(author: UUID? = nil, restaurant: UUID? = nil, id: UUID? = nil, followingOnly: Bool = false, offset: Int = 0) async throws -> [LivePost] {
        var query = try client.from("posts").select(postSelection).eq("is_removed", value: false).eq("post_photos.is_removed", value: false)
        if let author { query = query.eq("author_id", value: author) }
        if let restaurant { query = query.eq("restaurant_id", value: restaurant) }
        if let id { query = query.eq("id", value: id) }
        if followingOnly {
            let me = try await userID()
            let follows: [LiveFollow] = try await client.from("follows").select().eq("follower_id", value: me).eq("status", value: "approved").execute().value
            guard !follows.isEmpty else { return [] }
            query = query.in("author_id", values: follows.map(\.following_id))
        }
        let rows: [LivePost] = try await query.order("created_at", ascending: false).order("id", ascending: false).range(from: offset, to: offset + 29).execute().value
        return try await hydrate(rows)
    }
    static func publicPosts(restaurant: UUID, dish: UUID? = nil) async throws -> [LivePost] {
        let rows = try await posts(restaurant: restaurant)
        return rows.filter { $0.profiles?.visibility == "public" && (dish == nil || $0.post_dishes.contains { $0.dish_id == dish }) }
    }
    static func collections(owner: UUID? = nil) async throws -> [LiveCollection] {
        let ownerID: UUID
        if let owner { ownerID = owner } else { ownerID = try await userID() }
        return try await client.from("collections").select().eq("owner_id", value: ownerID).order("created_at").execute().value
    }
    static func report(type: String, id: UUID, reason: String) async throws {
        let me = try await userID()
        _ = try await client.from("reports").insert(["reporter_id":me.uuidString,"target_type":type,"target_id":id.uuidString,"reason":reason]).execute()
    }
    static func removePost(_ id: UUID) async throws { _ = try await client.from("posts").update(["is_removed":true]).eq("id", value: id).execute() }
    static func follow(_ id: UUID, status: String) async throws {
        let me = try await userID()
        _ = try await client.from("follows").insert(["follower_id":me.uuidString,"following_id":id.uuidString,"status":status]).execute()
    }
    static func unfollow(follower: UUID, following: UUID) async throws { _ = try await client.from("follows").delete().eq("follower_id", value: follower).eq("following_id", value: following).execute() }
}
