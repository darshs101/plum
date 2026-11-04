import SwiftUI

struct RootTabView: View {
    @ObservedObject private var navigation = AppNavigation.shared
    @State private var openedRoute: NotificationRoute?
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
            NavigationStack { MessagesInboxView() }.tabItem { Image(systemName: "paperplane").accessibilityLabel("Messages") }.tag(AppTab.messages)
            ProfileView().tabItem { Image(systemName: "person").accessibilityLabel("Profile") }.tag(AppTab.profile)
        }
        .tint(.plum)
        .task(id: navigation.pendingNotification) {
            guard let route = navigation.pendingNotification else { return }
            guard let me = try? await PlumAPI.userID() else { return }
            navigation.pendingNotification = nil
            guard route.recipientID == nil || route.recipientID == me else { return }
            openedRoute = route
        }
        .sheet(item: $openedRoute) { route in
            NavigationStack {
                Group {
                    switch route.destination {
                    case .post: if let id = route.targetID { PostDetailView(id: id) }
                    case .profile: if let id = route.targetID { MemberProfileView(id: id) }
                    case .requests: LiveNotificationsView()
                    }
                }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { openedRoute = nil } } }
            }
        }
    }
}

enum AppTab: String { case home, explore, create, messages, profile }

extension Color { static let plum = Color(red: 0.35, green: 0.08, blue: 0.24) }

extension ShapeStyle where Self == Color {
    static var plum: Color { Color.plum }
}
