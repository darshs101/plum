import SwiftUI

@main
struct PlumApp: App {
    @StateObject private var session = SessionStore()
    var body: some Scene { WindowGroup { Group { switch session.state { case .loading: ProgressView("Loading Plum…"); case .signedOut: WelcomeView(session: session); case .signedIn: RootTabView(); case .failed(let message): ContentUnavailableView("Plum needs setup", systemImage: "exclamationmark.triangle", description: Text(message)) } }.task { await session.restore() } } }
}
