import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView().tabItem { Label("Home", systemImage: "house") }
            ExploreView().tabItem { Label("Explore", systemImage: "magnifyingglass") }
            CreatePostView().tabItem { Label("Create", systemImage: "plus") }
            ProfileView().tabItem { Label("Profile", systemImage: "person") }
        }
        .tint(.plum)
    }
}

extension Color { static let plum = Color(red: 0.35, green: 0.08, blue: 0.24) }

extension ShapeStyle where Self == Color {
    static var plum: Color { Color.plum }
}
