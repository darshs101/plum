import SwiftUI

/// One vertical scroll surface; each tasting retains its normal social actions.
struct ProfileDiaryView: View {
    let authorID: UUID
    let name: String
    @State private var posts: [LivePost]
    private let selectedPostID: UUID
    @State private var canLoadMore: Bool
    @State private var loadingMore = false
    @State private var error: String?
    @State private var reloadToken = 0

    init(authorID: UUID, name: String, initialPosts: [LivePost], selectedPostID: UUID, hasMore: Bool) {
        self.authorID = authorID; self.name = name
        _posts = State(initialValue: initialPosts)
        self.selectedPostID = selectedPostID
        _canLoadMore = State(initialValue: hasMore)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(posts) { post in
                        PostDetailView(id: post.id, embedded: true, onDeleted: { posts.removeAll { $0.id == post.id } }, initialPost: post, reloadToken: reloadToken)
                            .id(post.id)
                            .overlay(alignment: .bottom) { Divider() }
                            .onAppear { if post.id == posts.last?.id { Task { await loadMore() } } }
                    }
                    if let error { Text(error).foregroundStyle(.red).padding(); Button("Retry") { Task { await loadMore() } } }
                    if canLoadMore && error == nil {
                        if loadingMore { ProgressView("Loading more tastings…").padding() }
                        else { Button("Load more tastings") { Task { await loadMore() } }.padding().onAppear { Task { await loadMore() } } }
                    }
                    if posts.isEmpty { ContentUnavailableView("No tastings available", systemImage: "square.grid.3x3") }
                }.scrollTargetLayout()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("@\(name)").navigationBarTitleDisplayMode(.inline)
            .refreshable {
                do { posts = try await PlumAPI.posts(author: authorID); canLoadMore = posts.count == 30; error = nil; reloadToken += 1 }
                catch { self.error = error.localizedDescription }
            }
            .task {
                // Wait for the lazy stack's first layout before positioning. An
                // initial scrollPosition binding can be reset by that layout pass.
                await Task.yield()
                proxy.scrollTo(selectedPostID, anchor: .top)
            }
        }
    }
    private func loadMore() async {
        guard canLoadMore, !loadingMore else { return }; loadingMore = true; error = nil; defer { loadingMore = false }
        do {
            let more = try await PlumAPI.posts(author: authorID, offset: posts.count)
            let existing = Set(posts.map(\.id)); let fresh = more.filter { !existing.contains($0.id) }; posts += fresh
            canLoadMore = more.count == 30 && !fresh.isEmpty
        } catch { self.error = error.localizedDescription }
    }
}
