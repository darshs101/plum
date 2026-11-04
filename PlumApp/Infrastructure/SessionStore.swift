import Foundation
import Supabase
import AuthenticationServices
import CryptoKit
import Security

@MainActor final class SessionStore: ObservableObject {
    enum State { case loading, signedOut, signedIn, failed(String) }
    @Published private(set) var state: State = .loading
    @Published private(set) var needsOnboarding = false
    private let client = PlumServices.client
    private var appleNonce: String?
    private var authTask: Task<Void, Never>?

    init() {
        guard let client else { return }
        authTask = Task { [weak self] in
            for await (event, _) in client.auth.authStateChanges {
                guard !Task.isCancelled else { return }
                if event == .signedOut || event == .userDeleted { self?.needsOnboarding = false; self?.state = .signedOut }
            }
        }
    }
    deinit { authTask?.cancel() }

    func refreshIfSignedIn() async {
        guard case .signedIn = state else { return }
        do { try await finishSignIn() } catch { state = .failed(error.localizedDescription) }
    }

    func restore() async {
        guard let client else { state = .failed("Supabase configuration is missing."); return }
        do { _ = try await client.auth.session } catch { state = .signedOut; return }
        do { try await finishSignIn() } catch { state = .failed(error.localizedDescription) }
    }
    private func finishSignIn() async throws {
        guard let client else { throw SocialClientError.notConfigured }
        let user = try await client.auth.user()
        struct Profile: Decodable { let onboarding_completed_at: Date?; let suspended_at: Date? }
        let profile: Profile = try await client.from("profiles").select("onboarding_completed_at,suspended_at").eq("id", value: user.id).single().execute().value
        guard profile.suspended_at == nil else { throw PlumAuthError.suspended }
        needsOnboarding = profile.onboarding_completed_at == nil
        state = .signedIn
        do { try await NotificationRegistration.synchronizePermission() }
        catch { NotificationRegistration.report(error.localizedDescription) }
    }
    func signIn(email: String, password: String) async throws {
        guard let client else { throw SocialClientError.notConfigured }
        let identifier = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty, !password.isEmpty else { throw PlumAuthError.invalidCredentials }
        if identifier.contains("@") { try await client.auth.signIn(email: identifier, password: password) }
        else {
            let config = try SupabaseConfiguration.load()
            var request = URLRequest(url: config.url.appendingPathComponent("functions/v1/username-sign-in"))
            request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.httpBody = try JSONEncoder().encode(["username":identifier.lowercased(),"password":password])
            let (data,response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode
                let message: String
                switch status {
                case 404: message = "Username sign-in is not available yet. Please use your email address."
                case 429: message = "Too many sign-in attempts. Please wait 15 minutes and try again."
                case 503: message = "Username sign-in is temporarily unavailable. Please use your email address."
                default: message = "Invalid username or password. Please try again."
                }
                throw NSError(domain: "PlumAuth", code: status ?? 0, userInfo: [NSLocalizedDescriptionKey: message])
            }
            struct Tokens: Decodable { let access_token: String; let refresh_token: String }
            let tokens = try JSONDecoder().decode(Tokens.self, from: data)
            try await client.auth.setSession(accessToken: tokens.access_token, refreshToken: tokens.refresh_token)
        }
        try await finishSignIn()
    }
    /// Returns false when Supabase requires the email confirmation step.
    func signUp(email: String, password: String, username: String) async throws -> Bool {
        guard let client else { throw SocialClientError.notConfigured }
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.range(of: "^[a-z0-9_]{3,30}$", options: .regularExpression) != nil else { throw PlumAuthError.invalidUsername }
        guard password.count >= 8 else { throw PlumAuthError.shortPassword }
        let response: AuthResponse
        do {
            response = try await client.auth.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, data: ["username": .string(normalized), "display_name": .string(normalized)], redirectTo: URL(string: "plum://login-callback"))
        } catch {
            if error.localizedDescription.localizedCaseInsensitiveContains("Database error saving new user") { throw PlumAuthError.usernameUnavailable }
            throw error
        }
        guard response.session != nil else { return false }
        try await finishSignIn()
        return true
    }
    func verifyEmail(email: String, code: String) async throws {
        guard let client else { throw SocialClientError.notConfigured }
        try await client.auth.verifyOTP(email: email, token: code, type: .signup)
        try await finishSignIn()
    }
    func handleCallback(_ url: URL) async throws {
        guard let client else { throw SocialClientError.notConfigured }
        _ = try await client.auth.session(from: url)
        try await finishSignIn()
    }
    func completeOnboarding(city: String, neighborhood: String) async throws {
        guard let client else { throw SocialClientError.notConfigured }
        let user = try await client.auth.user()
        struct Update: Encodable { let city: String?; let neighborhood: String?; let onboarding_completed_at: Date }
        _ = try await client.from("profiles").update(Update(city: city.isEmpty ? nil : city, neighborhood: neighborhood.isEmpty ? nil : neighborhood, onboarding_completed_at: .now)).eq("id", value: user.id).execute()
        needsOnboarding = false
    }
    func signOut() async {
        guard let client else { state = .signedOut; return }
        // A denied token cleanup or offline server must not trap an account on this device.
        try? await NotificationRegistration.unregister()
        do { try await client.auth.signOut(scope: .local) }
        catch { /* The SDK clears local credentials before requesting remote revocation. */ }
        AppNavigation.shared.pendingNotification = nil
        needsOnboarding = false; state = .signedOut
    }
    func signInWithGoogle() async throws {
        guard let client else { throw SocialClientError.notConfigured }
        _ = try await client.auth.signInWithOAuth(provider: .google, redirectTo: URL(string: "plum://login-callback")) { session in
            session.prefersEphemeralWebBrowserSession = false
        }
        try await finishSignIn()
    }
    func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = UUID().uuidString + UUID().uuidString
        appleNonce = nonce
        request.requestedScopes = [.email, .fullName]
        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    func signInWithApple(_ authorization: ASAuthorization) async throws {
        guard let client else { throw SocialClientError.notConfigured }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8), let nonce = appleNonce else {
            throw NSError(domain: "Plum", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple did not return a sign-in token. Please try again."])
        }
        _ = try await client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: token, nonce: nonce))
        appleNonce = nil
        try await finishSignIn()
    }
}

private enum PlumAuthError: LocalizedError {
    case suspended, invalidCredentials, invalidUsername, shortPassword, usernameUnavailable
    var errorDescription: String? {
        switch self {
        case .suspended: "This account is suspended. You can sign out or try again after it has been restored."
        case .invalidCredentials: "Enter your email or username and password."
        case .invalidUsername: "Use 3–30 letters, numbers, or underscores for your username."
        case .shortPassword: "Use at least 8 characters for your password."
        case .usernameUnavailable: "That username could not be registered. Try a different username, or sign in if you already have an account."
        }
    }
}
