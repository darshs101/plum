import SwiftUI

@main
struct PlumApp: App {
    @UIApplicationDelegateAdaptor(PlumAppDelegate.self) private var appDelegate
    @StateObject private var session = SessionStore()
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
                    VStack { ContentUnavailableView("Couldn’t load Plum", systemImage: "exclamationmark.triangle", description: Text(message)); Button("Try again") { Task { await session.restore() } } }
                }
            }
            .environmentObject(session)
            .task { await session.restore() }
            .onOpenURL { url in Task { do { try await session.handleCallback(url) } catch { callbackError = error.localizedDescription } } }
            .alert("Sign-in failed", isPresented: Binding(get: { callbackError != nil }, set: { if !$0 { callbackError = nil } })) { Button("OK") { callbackError = nil } } message: { Text(callbackError ?? "") }
        }
    }
}
