import Foundation
import Supabase

/// The only directory/composer implementation used by the app. It uses the
/// session-bound client, so every table and storage request is subject to RLS.
actor SupabaseDirectoryService: DirectoryServing {
    private let client: SupabaseClient

    init(configuration: SupabaseConfiguration) {
        client = SupabaseClient(supabaseURL: configuration.url, supabaseKey: configuration.publishableKey)
    }

    func search(query: String, filters: DirectoryFilters) async throws -> [DirectoryResult] {
        let rows: [SearchRow] = try await client.rpc("search_public", params: SearchParams(
            searchText: query, cuisineFilter: filters.cuisine, neighborhoodFilter: filters.neighborhood,
            priceFilter: filters.priceLevel
        )).execute().value
        return rows.compactMap { row in
            guard let kind = DirectorySearchKind(rawValue: row.kind) else { return nil }
            return DirectoryResult(id: row.id, kind: kind, title: row.label, subtitle: row.subtitle,
                                   priceLevel: nil, restaurantID: nil, isExactMatch: row.score >= 100)
        }
    }

    func curatedCollections() async throws -> [DirectoryResult] {
        let rows: [CuratedRow] = try await client.from("collections").select("id,title,profiles!inner(username)")
            .eq("is_curated", value: true).eq("is_public", value: true).execute().value
        return rows.map { .init(id: $0.id, kind: .collection, title: $0.title, subtitle: $0.profiles.username, priceLevel: nil, restaurantID: nil, isExactMatch: false) }
    }

    func popularNearby() async throws -> [DirectoryResult] {
        let rows: [RestaurantRow] = try await client.from("restaurants").select("id,name,address,neighborhood,price_level")
            .order("created_at", ascending: false).limit(20).execute().value
        return rows.map { .init(id: $0.id, kind: .restaurant, title: $0.name, subtitle: $0.neighborhood ?? $0.address, priceLevel: $0.priceLevel, restaurantID: $0.id, isExactMatch: false) }
    }

    func createDish(restaurantID: UUID, name: String) async throws -> Dish {
        let user = try await client.auth.user()
        let row: DishRow = try await client.from("dishes").insert(NewDish(restaurantID: restaurantID, name: name, createdBy: user.id)).select().single().execute().value
        return Dish(id: row.id, restaurantID: row.restaurantID, name: row.name)
    }

    func createPost(_ draft: PostDraftRequest) async throws {
        guard !draft.dishes.isEmpty, !draft.photos.isEmpty else { throw PlumError.invalidPost }
        let user = try await client.auth.user(); let postID = UUID()
        let post: PostRow = try await client.from("posts").insert(NewPost(id: postID, authorID: user.id, restaurantID: draft.restaurantID, caption: draft.caption, visitDate: draft.visitDate)).select().single().execute().value
        let dishes = draft.dishes.compactMap { draft -> NewPostDish? in
            guard let dishID = draft.dishID else { return nil }
            return NewPostDish(postID: post.id, dishID: dishID, rating: draft.rating)
        }
        _ = try await client.from("post_dishes").insert(dishes).execute()
        for (index, photo) in draft.photos.enumerated() {
            let path = "\(user.id.uuidString)/\(post.id.uuidString)/\(photo.id.uuidString).jpg"
            try await client.storage.from("post-media").upload(path, data: photo.data, options: FileOptions(contentType: photo.contentType, upsert: false))
            _ = try await client.from("post_photos").insert(NewPostPhoto(postID: post.id, storagePath: path, position: index)).execute()
        }
    }
}

enum PlumServices {
    static let directory: any DirectoryServing = {
        guard let configuration = try? SupabaseConfiguration.load() else { return UnconfiguredDirectoryService() }
        return SupabaseDirectoryService(configuration: configuration)
    }()
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
