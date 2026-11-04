import Foundation
import Supabase

actor SupabaseSocialClient: SocialClient {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func setLike(postID: UUID, isLiked: Bool) async throws { let user = try await client.auth.user(); if isLiked { _ = try await client.from("likes").insert(["post_id": postID.uuidString, "user_id": user.id.uuidString]).execute() } else { _ = try await client.from("likes").delete().eq("post_id", value: postID).eq("user_id", value: user.id).execute() } }
}

extension PlumServices { static let social: any SocialClient = { guard let client = PlumServices.client else { return UnavailableSocialClient() }; return SupabaseSocialClient(client: client) }() }
