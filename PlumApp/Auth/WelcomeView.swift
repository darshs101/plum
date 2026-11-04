import AuthenticationServices
import SwiftUI

struct WelcomeView: View {
    @ObservedObject var session: SessionStore
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var showEmail = false
    @State private var creatingAccount = true
    @State private var working = false
    @State private var error: String?
    @State private var confirmationPending = false
    @State private var code = ""

    var body: some View {
        NavigationStack {
            Group {
                if showEmail { emailForm } else { welcome }
            }
            .background(PlumStyle.cream.ignoresSafeArea())
            .navigationTitle(showEmail ? (creatingAccount ? "Create account" : "Sign in") : "Plum")
            .alert("Couldn’t continue", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("A food journal\nfor your city.").font(.system(size: 38, weight: .semibold, design: .serif)).foregroundStyle(.plum)
            Text("Log dishes, save places, and follow people whose taste you trust.").foregroundStyle(.secondary)
            SignInWithAppleButton(.continue) { session.prepareApple($0) } onCompletion: { result in
                run { try await session.signInWithApple(result.get()) }
            }.signInWithAppleButtonStyle(.black).frame(height: 50).disabled(working)
            Button { run { try await session.signInWithGoogle() } } label: {
                Label("Continue with Google", systemImage: "g.circle.fill").frame(maxWidth: .infinity)
            }.buttonStyle(.bordered).tint(.plum).disabled(working)
            Button("Create an account with email") { creatingAccount = true; showEmail = true }.frame(maxWidth: .infinity).disabled(working)
            Button("Already have an account? Sign in") { creatingAccount = false; showEmail = true }.frame(maxWidth: .infinity).disabled(working)
            if working { ProgressView("Signing in…").frame(maxWidth: .infinity) }
            Spacer()
        }.padding(24)
    }
    private var validUsername: Bool { username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().range(of: "^[a-z0-9_]{3,30}$", options: .regularExpression) != nil }
    private var emailForm: some View {
        Form {
            if confirmationPending {
                Section("Confirm your email") {
                    Text("Your account was created. Open the confirmation link sent to \(email), then return here and sign in. If the email contains a code, enter it below.")
                    TextField("Confirmation code", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                    Button("Confirm code") { run { try await session.verifyEmail(email: email, code: code) } }.disabled(working || code.isEmpty)
                    Button("Return to sign in") { confirmationPending = false; creatingAccount = false }
                }
            } else {
                Section("Account") {
                    TextField(creatingAccount ? "Email" : "Email or username", text: $email).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.emailAddress).textContentType(.emailAddress).accessibilityIdentifier("auth.email")
                    if creatingAccount {
                        TextField("Username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.username).accessibilityIdentifier("auth.username")
                        Text("3–30 lowercase letters, numbers, or underscores.").font(.caption).foregroundStyle(.secondary)
                    }
                    SecureField("Password", text: $password).textContentType(.password).accessibilityIdentifier("auth.password")
                    if creatingAccount { Text("Use at least 8 characters.").font(.caption).foregroundStyle(.secondary) }
                }
                Section {
                    Button(creatingAccount ? "Create account" : "Sign in") {
                        run {
                            if creatingAccount { confirmationPending = try await !session.signUp(email: email, password: password, username: username) }
                            else { try await session.signIn(email: email, password: password) }
                        }
                    }.disabled(working || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (creatingAccount && !email.contains("@")) || password.isEmpty || (creatingAccount && (!validUsername || password.count < 8))).accessibilityIdentifier("auth.submit")
                    Button(creatingAccount ? "I already have an account" : "Create a new account") { creatingAccount.toggle() }.disabled(working)
                }
            }
            if working { ProgressView("Please wait…") }
        }
        .scrollContentBackground(.hidden)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Back") { showEmail = false }.disabled(working) } }
    }
    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        guard !working else { return }
        working = true
        Task { defer { working = false }; do { try await action() } catch { self.error = error.localizedDescription } }
    }
}

struct OnboardingView: View {
    @ObservedObject var session: SessionStore
    @State private var city = "Atlanta"
    @State private var neighborhood = ""
    @State private var working = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Your area (optional)") { TextField("City", text: $city); TextField("Neighborhood", text: $neighborhood) }
                Section("Make Plum yours") { Text("Log a dish at a place you know with the + tab. Find places to try in Explore and save them to your private Saved Places collection.") }
                if let error { Text(error).foregroundStyle(.red) }
                Button("Get started") { finish(skip: false) }.disabled(working)
                Button("Skip for now") { finish(skip: true) }.disabled(working)
                if working { ProgressView() }
            }.navigationTitle("Welcome to Plum")
        }
    }
    private func finish(skip: Bool) { working = true; Task { defer { working = false }; do { try await session.completeOnboarding(city: skip ? "" : city, neighborhood: skip ? "" : neighborhood) } catch { self.error = error.localizedDescription } } }
}
