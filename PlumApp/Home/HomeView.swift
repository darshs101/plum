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
                        StarterFollowingView()
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
                LivePostContent(post: post).foregroundStyle(.primary)
            }.buttonStyle(.plain)
        }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
struct LivePostContent: View {
    let post: LivePost
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PostSlideshow(photos: post.post_photos)
            Text(post.restaurants?.name ?? "Restaurant").font(.headline)
            ForEach(post.post_dishes) { dish in HStack { Text(dish.dishes?.name ?? "Dish"); Spacer(); Label(dish.rating.formatted(), systemImage: "star.fill") } }
            if let caption = post.caption, !caption.isEmpty { Text(caption) }
            Text(post.displayDate, style: .date).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("post.date.\(post.id.uuidString)")
        }
    }
}
struct PostSlideshow: View {
    let photos: [LivePhoto]
    var body: some View {
        TabView { ForEach(photos) { photo in
            AsyncImage(url: photo.url) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else if phase.error != nil || photo.url == nil { Rectangle().fill(Color.plum.opacity(0.1)).overlay(Label("Photo unavailable", systemImage: "photo").foregroundStyle(.secondary)) }
                else { Rectangle().fill(Color.plum.opacity(0.1)).overlay(ProgressView()) }
            }.clipped()
        } }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never)).frame(height: 280).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)).plumPhotoEdge(radius: 14)
    }
}
struct RetryState: View {
    let title: String; let message: String; let retry: () async -> Void
    var body: some View { ContentUnavailableView { Label(title, systemImage: "exclamationmark.triangle") } description: { Text(message) } actions: { Button("Try again") { Task { await retry() } }.buttonStyle(.bordered).tint(.plum) } }
}

private struct StarterFollowingView: View {
    @State private var suggestions: [LiveProfile] = []
    @State private var error: String?
    @State private var working: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ContentUnavailableView("Your table is waiting", systemImage: "person.2", description: Text("Follow Atlanta food people to see their latest dishes here."))
            NavigationLink("Explore Atlanta") { ExploreView() }.buttonStyle(.borderedProminent).tint(.plum).frame(maxWidth: .infinity)
            if !suggestions.isEmpty { Text("Atlanta people to follow").font(.headline); ForEach(suggestions) { person in HStack { VStack(alignment: .leading) { Text(person.display_name); Text("@\(person.username)").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button(working == person.id ? "Following…" : "Follow") { follow(person.id) }.buttonStyle(.bordered).disabled(working != nil) } } }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }.task { await loadSuggestions() }
    }
    private func loadSuggestions() async { do { let mine = try await PlumAPI.userID(); suggestions = try await PlumAPI.client.from("profiles").select().eq("visibility", value: "public").neq("id", value: mine).limit(8).execute().value } catch { self.error = error.localizedDescription } }
    private func follow(_ id: UUID) { working = id; Task { defer { working = nil }; do { try await PlumAPI.follow(id, status: "approved"); suggestions.removeAll { $0.id == id } } catch { self.error = error.localizedDescription } } }
}
