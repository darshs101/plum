import SwiftUI

struct RootTabView: View {
    @State private var openedPost: OpenedPost?
    private struct OpenedPost: Identifiable { let id: UUID }
    @State private var selection: AppTab

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let valueIndex = arguments.firstIndex(of: "-plum-tab"), arguments.indices.contains(valueIndex + 1),
           let tab = AppTab(rawValue: arguments[valueIndex + 1]) {
            _selection = State(initialValue: tab)
        } else {
            _selection = State(initialValue: .home)
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView().tabItem { Image(systemName: "house").accessibilityLabel("Home") }.tag(AppTab.home)
            ExploreView().tabItem { Image(systemName: "magnifyingglass").accessibilityLabel("Explore") }.tag(AppTab.explore)
            CreatePostView().tabItem { Image(systemName: "plus").accessibilityLabel("Create") }.tag(AppTab.create)
            ProfileView().tabItem { Image(systemName: "person").accessibilityLabel("Profile") }.tag(AppTab.profile)
        }
        .tint(.plum)
        .onReceive(NotificationCenter.default.publisher(for: .plumOpenPost)) { notification in if let id = notification.object as? UUID { openedPost = OpenedPost(id: id) } }
        .sheet(item: $openedPost) { post in NavigationStack { PostDetailView(id: post.id) } }
    }
}

enum AppTab: String { case home, explore, create, profile }

extension Color { static let plum = Color(red: 0.35, green: 0.08, blue: 0.24) }

extension ShapeStyle where Self == Color {
    static var plum: Color { Color.plum }
}
