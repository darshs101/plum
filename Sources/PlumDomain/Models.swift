import Foundation

public typealias ID = UUID

public enum AccountVisibility: String, Codable, Sendable { case `public`, `private` }
public enum FollowState: String, Codable, Sendable { case requested, approved }
public enum CollectionKind: String, Codable, Sendable { case savedPlaces, standard, ranked }

public struct PlumUser: Identifiable, Codable, Hashable, Sendable {
    public let id: ID
    public var username: String
    public var displayName: String
    public var visibility: AccountVisibility
    public var avatarURL: URL?
    public init(id: ID = ID(), username: String, displayName: String, visibility: AccountVisibility = .public, avatarURL: URL? = nil) {
        self.id = id; self.username = username; self.displayName = displayName; self.visibility = visibility; self.avatarURL = avatarURL
    }
}

public struct Restaurant: Identifiable, Codable, Hashable, Sendable {
    public let id: ID
    public var name: String
    public var neighborhood: String
    public var address: String
    public var cuisine: String
    public var priceLevel: Int
    public var photoURL: URL?
    public init(id: ID = ID(), name: String, neighborhood: String, address: String, cuisine: String, priceLevel: Int, photoURL: URL? = nil) {
        self.id = id; self.name = name; self.neighborhood = neighborhood; self.address = address; self.cuisine = cuisine; self.priceLevel = priceLevel; self.photoURL = photoURL
    }
}

public struct Dish: Identifiable, Codable, Hashable, Sendable {
    public let id: ID
    public let restaurantID: ID
    public var name: String
    public var aliases: [String]
    public init(id: ID = ID(), restaurantID: ID, name: String, aliases: [String] = []) { self.id = id; self.restaurantID = restaurantID; self.name = name; self.aliases = aliases }
}

public struct DishRating: Codable, Hashable, Sendable {
    public let dishID: ID
    public var stars: Double
    public init(dishID: ID, stars: Double) { self.dishID = dishID; self.stars = stars }
}

public struct FoodPost: Identifiable, Codable, Hashable, Sendable {
    public let id: ID
    public let authorID: ID
    public var restaurantID: ID
    public var dishRatings: [DishRating]
    public var photoURLs: [URL]
    public var caption: String?
    public var visitDate: Date?
    public var createdAt: Date
    public init(id: ID = ID(), authorID: ID, restaurantID: ID, dishRatings: [DishRating], photoURLs: [URL], caption: String? = nil, visitDate: Date? = nil, createdAt: Date = .now) {
        self.id = id; self.authorID = authorID; self.restaurantID = restaurantID; self.dishRatings = dishRatings; self.photoURLs = photoURLs; self.caption = caption; self.visitDate = visitDate; self.createdAt = createdAt
    }
    public var isValid: Bool { !dishRatings.isEmpty && !photoURLs.isEmpty && dishRatings.allSatisfy { (0.5...5).contains($0.stars) && ($0.stars * 2).rounded() == $0.stars * 2 } }
}

public struct PlumCollection: Identifiable, Codable, Hashable, Sendable {
    public let id: ID
    public let ownerID: ID
    public var title: String
    public var kind: CollectionKind
    public var isPublic: Bool
    public var restaurantIDs: [ID]
    public var postIDs: [ID]
    public init(id: ID = ID(), ownerID: ID, title: String, kind: CollectionKind = .standard, isPublic: Bool, restaurantIDs: [ID] = [], postIDs: [ID] = []) { self.id = id; self.ownerID = ownerID; self.title = title; self.kind = kind; self.isPublic = isPublic; self.restaurantIDs = restaurantIDs; self.postIDs = postIDs }
}

public struct Comment: Identifiable, Codable, Hashable, Sendable { public let id: ID; public let postID: ID; public let authorID: ID; public var body: String; public var createdAt: Date }
public struct AppNotification: Identifiable, Codable, Hashable, Sendable { public let id: ID; public var title: String; public var detail: String; public var createdAt: Date; public var isRead: Bool }
