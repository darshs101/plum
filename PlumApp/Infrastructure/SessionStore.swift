import Foundation
import Supabase

@MainActor final class SessionStore: ObservableObject {
    enum State { case loading, signedOut, signedIn, failed(String) }
    @Published private(set) var state: State = .loading
    private let client: SupabaseClient?

    init() {
        if let config = try? SupabaseConfiguration.load() { client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.publishableKey) } else { client = nil }
    }
    func restore() async { guard let client else { state = .failed("Supabase configuration is missing."); return }; do { _ = try await client.auth.user(); state = .signedIn } catch { state = .signedOut } }
    func signIn(email: String, password: String) async throws { guard let client else { throw SocialClientError.notConfigured }; try await client.auth.signIn(email: email, password: password); state = .signedIn }
    func signUp(email: String, password: String, username: String) async throws { guard let client else { throw SocialClientError.notConfigured }; _ = try await client.auth.signUp(email: email, password: password, data: ["username": .string(username)]); state = .signedIn }
    func signOut() async { guard let client else { return }; try? await client.auth.signOut(); state = .signedOut }
}
