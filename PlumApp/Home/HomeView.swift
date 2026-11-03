import SwiftUI

struct HomeView: View {
    @State private var posts: [LivePost] = []
    @State private var loading = true
    @State private var canLoadMore = false
    @State private var loadingMore = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    if loading { ProgressView("Loading your following feed…") }
                    if let error { RetryState(title: "Couldn’t load your feed", message: error) { await load() } }
                    if !loading && error == nil && posts.isEmpty {
                        ContentUnavailableView("Your table is waiting", systemImage: "person.2", description: Text("Follow people in Explore to see their latest dishes here."))
                        NavigationLink("Explore Atlanta") { ExploreView() }.buttonStyle(.borderedProminent)
                    }
                    ForEach(posts) { post in LivePostCard(post: post) }
                    if canLoadMore { Button(loadingMore ? "Loading…" : "Load more") { Task { loadingMore = true; defer { loadingMore = false }; do { let more = try await PlumAPI.posts(followingOnly: true, offset: posts.count); posts += more; canLoadMore = more.count == 30 } catch { self.error = error.localizedDescription } } }.disabled(loadingMore) }
                }.padding(16)
            }.refreshable { await load() }.navigationTitle("Following")
                .background(PlumStyle.cream.ignoresSafeArea()).task { await load() }
        }.tint(.plum)
    }
    private func load() async { loading = true; error = nil; defer { loading = false }; do { posts = try await PlumAPI.posts(followingOnly: true); canLoadMore = posts.count == 30 } catch { self.error = error.localizedDescription } }
}

struct LivePostCard: View {
    let post: LivePost
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink { MemberProfileView(id: post.author_id) } label: { Label("@\(post.profiles?.username ?? "Plum member")", systemImage: "person.crop.circle") }
            NavigationLink { PostDetailView(id: post.id) } label: {
                VStack(alignment: .leading, spacing: 10) {
                    PostSlideshow(photos: post.post_photos)
                    Text(post.restaurants?.name ?? "Restaurant").font(.headline)
                    ForEach(post.post_dishes) { dish in HStack { Text(dish.dishes?.name ?? "Dish"); Spacer(); Label(dish.rating.formatted(), systemImage: "star.fill") } }
                    if let caption = post.caption, !caption.isEmpty { Text(caption) }
                    Text(post.created_at, style: .date).font(.caption).foregroundStyle(.secondary)
                }.foregroundStyle(.primary)
            }.buttonStyle(.plain)
        }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}
struct PostSlideshow: View {
    let photos: [LivePhoto]
    var body: some View {
        TabView { ForEach(photos) { photo in AsyncImage(url: photo.url) { image in image.resizable().scaledToFill() } placeholder: { Rectangle().fill(Color.plum.opacity(0.1)).overlay(ProgressView()) }.clipped() } }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never)).frame(height: 280).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
struct RetryState: View {
    let title: String; let message: String; let retry: () async -> Void
    var body: some View { ContentUnavailableView { Label(title, systemImage: "exclamationmark.triangle") } description: { Text(message) } actions: { Button("Try again") { Task { await retry() } }.buttonStyle(.bordered).tint(.plum) } }
}
