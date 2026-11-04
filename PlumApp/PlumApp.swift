import SwiftUI

@main
struct PlumApp: App {
    @UIApplicationDelegateAdaptor(PlumAppDelegate.self) private var appDelegate
    @StateObject private var session = SessionStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var callbackError: String?
    var body: some Scene {
        WindowGroup {
            Group {
                switch session.state {
                case .loading: ProgressView("Loading Plum…")
                case .signedOut: WelcomeView(session: session)
                case .signedIn:
                    if session.needsOnboarding { OnboardingView(session: session) }
                    else { RootTabView() }
                case .failed(let message):
                    VStack { ContentUnavailableView("Couldn’t load Plum", systemImage: "exclamationmark.triangle", description: Text(message)); Button("Try again") { Task { await session.restore() } }; Button("Sign out") { Task { await session.signOut() } } }
                }
            }
            .environmentObject(session)
            .task { await session.restore() }
            .onOpenURL { url in
                guard url.scheme == "plum", url.host == "login-callback" else { return }
                Task { do { try await session.handleCallback(url) } catch { callbackError = error.localizedDescription } }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await session.refreshIfSignedIn() } }
            }
            .alert("Sign-in failed", isPresented: Binding(get: { callbackError != nil }, set: { if !$0 { callbackError = nil } })) { Button("OK") { callbackError = nil } } message: { Text(callbackError ?? "") }
        }
    }
}
