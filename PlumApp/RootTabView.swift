import SwiftUI

struct RootTabView: View {
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
            HomeView().tabItem { Label("Home", systemImage: "house") }.tag(AppTab.home)
            ExploreView().tabItem { Label("Explore", systemImage: "magnifyingglass") }.tag(AppTab.explore)
            CreatePostView().tabItem { Label("Create", systemImage: "plus") }.tag(AppTab.create)
            ProfileView().tabItem { Label("Profile", systemImage: "person") }.tag(AppTab.profile)
        }
        .tint(.plum)
    }
}

enum AppTab: String { case home, explore, create, profile }

extension Color { static let plum = Color(red: 0.35, green: 0.08, blue: 0.24) }

extension ShapeStyle where Self == Color {
    static var plum: Color { Color.plum }
}
