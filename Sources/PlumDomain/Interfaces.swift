import Foundation

public protocol PlumRepository: Sendable {
    func homeFeed(for userID: ID) async throws -> [FoodPost]
    func explore(query: String) async throws -> [Restaurant]
    func createPost(_ post: FoodPost) async throws
    func collections(for userID: ID) async throws -> [PlumCollection]
    func notifications(for userID: ID) async throws -> [AppNotification]
}

public protocol SessionProviding: Sendable {
    var currentUser: PlumUser? { get async }
}

public enum PlumError: LocalizedError, Sendable {
    case invalidPost
    case unavailable
    public var errorDescription: String? { switch self { case .invalidPost: "Each post needs a half-star dish rating and at least one photo."; case .unavailable: "This feature is temporarily unavailable." } }
}
