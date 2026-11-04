import Foundation

protocol SocialClient: Sendable { func setLike(postID: UUID, isLiked: Bool) async throws }
enum SocialClientError: LocalizedError {
    case notConfigured, permissionDenied
    var errorDescription: String? {
        switch self {
        case .notConfigured: "Connect your Plum account to load live activity."
        case .permissionDenied: "This content is unavailable or you don’t have permission to view it."
        }
    }
}
struct UnavailableSocialClient: SocialClient {
    func setLike(postID: UUID, isLiked: Bool) async throws { throw SocialClientError.notConfigured }
}
