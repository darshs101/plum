import Foundation
import Supabase

/// The only directory/composer implementation used by the app. It uses the
/// session-bound client, so every table and storage request is subject to RLS.
actor SupabaseDirectoryService: DirectoryServing {
    private let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    func search(query: String, filters: DirectoryFilters) async throws -> [DirectoryResult] {
        let rows: [SearchRow] = try await client.rpc("search_public", params: SearchParams(
            searchText: query, cuisineFilter: filters.cuisine, neighborhoodFilter: filters.neighborhood,
            priceFilter: filters.priceLevel
        )).execute().value
        let ids = rows.filter { $0.kind == "dish" }.map(\.id)
        let dishes: [DishRow] = ids.isEmpty ? [] : try await client.from("dishes").select("id,name,restaurant_id").in("id", values: ids).execute().value
        return rows.compactMap { row in
            guard let kind = DirectorySearchKind(rawValue: row.kind) else { return nil }
            return DirectoryResult(id: row.id, kind: kind, title: row.label, subtitle: row.subtitle,
                priceLevel: nil, restaurantID: kind == .restaurant ? row.id : dishes.first(where: { $0.id == row.id })?.restaurantID, isExactMatch: row.score >= 100)
        }
    }

    func curatedCollections() async throws -> [DirectoryResult] {
        let rows: [CuratedRow] = try await client.from("collections").select("id,title,profiles!inner(username)")
            .eq("is_curated", value: true).eq("is_public", value: true).execute().value
        return rows.map { .init(id: $0.id, kind: .collection, title: $0.title, subtitle: $0.profiles.username, priceLevel: nil, restaurantID: nil, isExactMatch: false) }
    }

    func popularNearby() async throws -> [DirectoryResult] {
        struct Popular: Decodable { let restaurant_id: UUID; let rating_count: Int }
        let popular: [Popular] = try await client.from("public_restaurant_aggregates").select("restaurant_id,rating_count").order("rating_count", ascending: false).limit(20).execute().value
        let rows: [RestaurantRow]
        if popular.isEmpty { rows = try await client.from("restaurants").select("id,name,address,neighborhood,price_level").order("created_at", ascending: false).limit(20).execute().value }
        else { rows = try await client.from("restaurants").select("id,name,address,neighborhood,price_level").in("id", values: popular.map(\.restaurant_id)).execute().value }
        return rows.sorted { left, right in (popular.firstIndex { $0.restaurant_id == left.id } ?? 999) < (popular.firstIndex { $0.restaurant_id == right.id } ?? 999) }.map { .init(id: $0.id, kind: .restaurant, title: $0.name, subtitle: $0.neighborhood ?? $0.address, priceLevel: $0.priceLevel, restaurantID: $0.id, isExactMatch: false) }
    }

    func createDish(restaurantID: UUID, name: String) async throws -> Dish {
        let user = try await client.auth.user()
        let row: DishRow = try await client.from("dishes").insert(NewDish(restaurantID: restaurantID, name: name, createdBy: user.id)).select().single().execute().value
        return Dish(id: row.id, restaurantID: row.restaurantID, name: row.name)
    }

    func restaurant(id: UUID) async throws -> Restaurant {
        var resolved = id
        struct Merge: Decodable { let target_id: UUID }
        for _ in 0..<10 {
            let merges: [Merge] = try await client.from("record_merge_history").select("target_id").eq("source_id", value: resolved).eq("record_type", value: "restaurant").execute().value
            guard let next = merges.first?.target_id else { break }; resolved = next
        }
        let row: FullRestaurant = try await client.from("restaurants").select().eq("id", value: resolved).single().execute().value
        let url = try await client.storage.from("restaurant-media").createSignedURL(path: row.photo_path, expiresIn: 300)
        return Restaurant(id: row.id, name: row.name, neighborhood: row.neighborhood ?? "", address: row.address, cuisine: row.cuisine ?? "", priceLevel: row.price_level ?? 0, photoURL: url)
    }
    func createRestaurant(_ draft: RestaurantDraft) async throws -> Restaurant {
        let user = try await client.auth.user()
        let id = UUID()
        let path = "\(user.id.uuidString.lowercased())/\(id.uuidString.lowercased())/photo.jpg"
        try await client.storage.from("restaurant-media").upload(path, data: draft.photo.data, options: FileOptions(contentType: draft.photo.contentType))
        do {
            if let original = draft.photo.originalData { try await client.storage.from("restaurant-media").upload(path + ".original", data: original, options: .init(contentType: draft.photo.originalContentType ?? "application/octet-stream")) }
            let row = FullRestaurant(id: id, name: draft.name, address: draft.address, neighborhood: draft.neighborhood, cuisine: draft.cuisine, price_level: draft.priceLevel, photo_path: path, created_by: user.id)
            _ = try await client.from("restaurants").insert(row).execute()
            let photoURL = try? await client.storage.from("restaurant-media").createSignedURL(path: path, expiresIn: 300)
            return Restaurant(id: id, name: draft.name, neighborhood: draft.neighborhood ?? "", address: draft.address, cuisine: draft.cuisine ?? "", priceLevel: draft.priceLevel ?? 0, photoURL: photoURL)
        } catch { _ = try? await client.storage.from("restaurant-media").remove(paths: [path, path + ".original"]); throw error }
    }
    func toggleSavedPlace(restaurantID: UUID, isSaved: Bool) async throws {
        let user = try await client.auth.user()
        struct Collection: Decodable { let id: UUID }
        let collection: Collection = try await client.from("collections").select("id").eq("owner_id", value: user.id).eq("kind", value: "saved_places").single().execute().value
        if isSaved {
            _ = try await client.from("collection_items").upsert(["collection_id": collection.id.uuidString, "restaurant_id": restaurantID.uuidString], onConflict: "collection_id,restaurant_id").execute()
        } else { _ = try await client.from("collection_items").delete().eq("collection_id", value: collection.id).eq("restaurant_id", value: restaurantID).execute() }
    }
    func createPost(_ draft: PostDraftRequest) async throws {
        guard !draft.dishes.isEmpty, !draft.photos.isEmpty, draft.dishes.allSatisfy({ $0.dishID != nil }) else { throw PlumError.invalidPost }
        let user = try await client.auth.user(); let postID = UUID()
        var paths: [String] = []; var originalPaths: [String] = []
        do {
            for photo in draft.photos {
                let path = "\(user.id.uuidString.lowercased())/\(postID.uuidString.lowercased())/\(photo.id.uuidString.lowercased()).jpg"
                try await client.storage.from("post-media").upload(path, data: photo.data, options: FileOptions(contentType: photo.contentType))
                paths.append(path)
                if let original = photo.originalData { let originalPath = path + ".original"; try await client.storage.from("post-media").upload(originalPath, data: original, options: .init(contentType: photo.originalContentType ?? "application/octet-stream")); originalPaths.append(originalPath) }
            }
            let params = SavePostParams(post_uuid: postID, restaurant_uuid: draft.restaurantID,
                dish_entries: draft.dishes.map { .init(dish_id: $0.dishID!, rating: $0.rating) },
                photo_paths: paths, caption_text: draft.caption, visited_on: draft.visitDate.map { ISO8601DateFormatter().string(from: $0).prefix(10).description })
            _ = try await client.rpc("save_post", params: params).execute()
        } catch { if !paths.isEmpty { _ = try? await client.storage.from("post-media").remove(paths: paths + originalPaths) }; throw error }
    }

}

private struct SearchParams: Encodable { let searchText: String; let cuisineFilter: String?; let neighborhoodFilter: String?; let priceFilter: Int?; enum CodingKeys: String, CodingKey { case searchText = "search_text", cuisineFilter = "cuisine_filter", neighborhoodFilter = "neighborhood_filter", priceFilter = "price_filter" } }
private struct SearchRow: Decodable { let kind: String; let id: UUID; let label: String; let subtitle: String; let score: Double }
private struct CuratedRow: Decodable { let id: UUID; let title: String; let profiles: UserName }
private struct UserName: Decodable { let username: String }
private struct RestaurantRow: Decodable { let id: UUID; let name, address: String; let neighborhood: String?; let priceLevel: Int?; enum CodingKeys: String, CodingKey { case id, name, address, neighborhood; case priceLevel = "price_level" } }
private struct DishRow: Decodable { let id, restaurantID: UUID; let name: String; enum CodingKeys: String, CodingKey { case id, name; case restaurantID = "restaurant_id" } }
private struct NewDish: Encodable { let restaurantID: UUID; let name: String; let createdBy: UUID; enum CodingKeys: String, CodingKey { case restaurantID = "restaurant_id", name; case createdBy = "created_by" } }
private struct PostRow: Decodable { let id: UUID }
private struct NewPost: Encodable { let id, authorID, restaurantID: UUID; let caption: String?; let visitDate: Date?; enum CodingKeys: String, CodingKey { case id, caption; case authorID = "author_id"; case restaurantID = "restaurant_id"; case visitDate = "visit_date" } }
private struct NewPostDish: Encodable { let postID, dishID: UUID; let rating: Double; enum CodingKeys: String, CodingKey { case rating; case postID = "post_id"; case dishID = "dish_id" } }
private struct NewPostPhoto: Encodable { let postID: UUID; let storagePath: String; let position: Int; enum CodingKeys: String, CodingKey { case position; case postID = "post_id"; case storagePath = "storage_path" } }

struct SavePostParams: Encodable { let post_uuid: UUID; let restaurant_uuid: UUID; let dish_entries: [SavePostDish]; let photo_paths: [String]; let caption_text: String?; let visited_on: String? }
struct SavePostDish: Encodable { let dish_id: UUID; let rating: Double }
private struct FullRestaurant: Codable { let id: UUID; let name: String; let address: String; let neighborhood: String?; let cuisine: String?; let price_level: Int?; let photo_path: String; let created_by: UUID }
