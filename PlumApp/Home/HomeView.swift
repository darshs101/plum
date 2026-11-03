import SwiftUI

struct HomeView: View {
    @StateObject private var store = SocialStore(client: PlumServices.social)
    var body: some View {
        NavigationStack {
            Group {
                switch store.feedState {
                case .idle, .loading: ProgressView("Loading your following feed…")
                case .empty: StarterFollowingView()
                case .failed(let message): RetryState(title: "Your feed isn’t available", message: message) { await store.loadFeed() }
                case .loaded: feed
                }
            }.navigationTitle("Following").background(PlumStyle.cream.ignoresSafeArea())
        }.tint(.plum).task { await store.loadFeed() }
    }
    private var feed: some View { ScrollView { LazyVStack(spacing: 16) { ForEach(store.entries) { entry in FeedCard(entry: entry) { await store.toggleLike(entry) } } }.padding(16) }.refreshable { await store.loadFeed() } }
}

private struct FeedCard: View {
    let entry: TimelineEntry; let onLike: () async -> Void
    var body: some View { VStack(alignment: .leading, spacing: 12) {
        Label("\(entry.authorName) · @\(entry.username)", systemImage: "person.crop.circle").font(.subheadline.weight(.semibold))
        AsyncImage(url: entry.photoURL) { image in image.resizable().scaledToFill() } placeholder: { Rectangle().fill(Color.plum.opacity(0.12)).overlay(Image(systemName: "photo").foregroundStyle(.plum)) }.frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        HStack { VStack(alignment: .leading) { Text(entry.dishName).font(.headline); Text("\(entry.restaurantName) · \(entry.neighborhood)").font(.caption).foregroundStyle(.secondary) }; Spacer(); Label(entry.rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill").foregroundStyle(.plum) }
        if let caption = entry.caption { Text(caption) }
        HStack(spacing: 20) { Button { Task { await onLike() } } label: { Label("\(entry.likes)", systemImage: entry.isLiked ? "heart.fill" : "heart") }.accessibilityLabel(entry.isLiked ? "Unlike post" : "Like post"); Label("\(entry.comments)", systemImage: "bubble.right"); Spacer(); Image(systemName: "bookmark") }.foregroundStyle(.plum)
    }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
}

private struct StarterFollowingView: View { var body: some View { ContentUnavailableView { Label("Your table is waiting", systemImage: "person.2.wave.2") } description: { Text("Follow Atlanta food people to see their newest dishes here. Explore local collections while you build your following list.") } actions: { NavigationLink("Explore Atlanta") { ExploreView() }.buttonStyle(.borderedProminent).tint(.plum) } } }

struct RetryState: View { let title: String; let message: String; let retry: () async -> Void; var body: some View { ContentUnavailableView { Label(title, systemImage: "exclamationmark.triangle") } description: { Text(message) } actions: { Button("Try again") { Task { await retry() } }.buttonStyle(.bordered).tint(.plum) } } }
