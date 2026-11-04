import SwiftUI

struct ProfileView: View { var body: some View { NavigationStack { MemberProfileView(id: nil) } } }
struct MemberProfileView: View {
    let id: UUID?
    var notificationIdentity: LiveProfile? = nil
    @EnvironmentObject private var session: SessionStore
    @State private var profile: LiveProfile?
    @State private var posts: [LivePost] = []
    @State private var collections: [LiveCollection] = []
    @State private var me: UUID?
    @State private var postCount = 0
    @State private var canLoadMore = false
    @State private var followers = 0
    @State private var following = 0
    @State private var relationship: String?
    @State private var isMutual = false
    @State private var error: String?
    @State private var loading = true
    @State private var working = false
    @State private var reporting = false
    @State private var newCollection = false
    @State private var isAdmin = false
    private var canViewContent: Bool { isOwner || profile?.visibility == "public" || relationship == "approved" }
    private var isOwner: Bool { id == nil || id == me }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if loading { ProgressView("Loading profile…") }
                if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
                if let profile {
                    profileHeader(profile)
                    if !isOwner {
                        HStack {
                            Button(relationship == nil ? "Follow" : relationship == "requested" ? "Cancel request" : "Unfollow") { perform {
                                guard let me else { return }
                                if relationship == nil { try await PlumAPI.follow(profile.id, status: profile.visibility == "private" ? "requested" : "approved") }
                                else { try await PlumAPI.unfollow(follower: me, following: profile.id) }; await load()
                            } }.buttonStyle(.bordered).disabled(working)
                            if isMutual { NavigationLink("Message") { ConversationView(otherUser: profile.id, otherName: profile.display_name) } }
                            Button("Report") { reporting = true }
                        }
                    }
                    if canViewContent {
                    Text("PHOTO DIARY").font(.caption.bold()).foregroundStyle(.plum)
                    if posts.isEmpty { Text("No tastings yet.").foregroundStyle(.secondary) }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                        ForEach(posts) { post in NavigationLink { PostDetailView(id: post.id) } label: { AsyncImage(url: post.post_photos.first?.url) { $0.resizable().scaledToFill() } placeholder: { Color.plum.opacity(0.12) }.frame(height: 115).clipped().plumPhotoEdge().accessibilityLabel(post.restaurants?.name ?? "Open tasting") } }
                    }
                    if canLoadMore { Button("Load more tastings") { perform { let more = try await PlumAPI.posts(author: profile.id, offset: posts.count); posts += more; canLoadMore = more.count == 30 } } }
                    HStack { Text("COLLECTIONS & RANKINGS").font(.caption.bold()).foregroundStyle(.plum); Spacer(); if isOwner { Button { newCollection = true } label: { Image(systemName: "plus.circle") }.accessibilityLabel("Create collection") } }
                    ForEach(collections) { collection in NavigationLink { CollectionDetailView(id: collection.id) } label: { HStack { Image(systemName: collection.kind == "ranked" ? "list.number" : "bookmark"); Text(collection.title); Spacer(); if !collection.is_public { Image(systemName: "lock") } }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 14)) } }
                    } else { Text("Only approved followers can view this private profile’s posts and collections.").foregroundStyle(.secondary) }

                }
            }.padding(20)
        }.navigationTitle(isOwner ? "Profile" : profile?.username ?? "Profile").navigationBarTitleDisplayMode(.inline)
            .background(PlumStyle.cream.ignoresSafeArea()).task { await load() }.refreshable { await load() }
            .toolbar { if isOwner {
                ToolbarItem(placement: .topBarLeading) { if let profile { NavigationLink { ProfileSettingsView(profile: profile, isAdmin: isAdmin) { Task { await load() } } } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings").accessibilityIdentifier("profile.settings") } }
                ToolbarItem(placement: .topBarTrailing) { NavigationLink { LiveNotificationsView() } label: { Image(systemName: "bell") }.accessibilityLabel("Notifications") }
            } }
            .sheet(isPresented: $newCollection, onDismiss: { Task { await load() } }) { NewCollectionView() }
            .sheet(isPresented: $reporting) { if let profile { ReportContentView(type: "account", id: profile.id) } }
    }
    private func profileHeader(_ p: LiveProfile) -> some View {
        VStack(spacing: 10) {
            ProfileAvatar(path: p.avatar_path, name: p.display_name, size: 84)
            Text(p.display_name).font(.title.bold()); Text("@\(p.username)").foregroundStyle(.secondary)
            if let city = p.city { Text(city).font(.subheadline) }
            if p.visibility == "private" { Label("Private account", systemImage: "lock").font(.caption) }
            if canViewContent { HStack { Text("\(postCount) posts"); Spacer(); Text("\(followers) followers"); Spacer(); Text("\(following) following") }.font(.caption) }
        }.frame(maxWidth: .infinity)
    }
    private func perform(_ operation: @escaping @MainActor () async throws -> Void) { working = true; error = nil; Task { defer { working = false }; do { try await operation() } catch { self.error = error.localizedDescription } } }
    private func load() async {
        loading = true; error = nil; defer { loading = false }
        do {
            isAdmin = try await PlumAPI.client.auth.session.user.appMetadata["plum_role"] == .string("admin")
            let me = try await PlumAPI.userID(); self.me = me; let target = id ?? me
            do { profile = try await PlumAPI.profile(target) }
            catch {
                // A notification recipient may see a requester's basic identity.
                // Content queries below still use the current session's RLS.
                guard let notificationIdentity, notificationIdentity.id == target else { throw error }
                profile = notificationIdentity
            }
            posts = try await PlumAPI.posts(author: target); canLoadMore = posts.count == 30
            postCount = try await PlumAPI.client.from("posts").select("id", head: true, count: .exact).eq("author_id", value: target).eq("is_removed", value: false).execute().count ?? 0
            collections = try await PlumAPI.collections(owner: target)
            let incoming: [LiveFollow] = try await PlumAPI.client.from("follows").select().eq("following_id", value: target).execute().value
            let outgoing: [LiveFollow] = try await PlumAPI.client.from("follows").select().eq("follower_id", value: target).eq("status", value: "approved").execute().value
            followers = incoming.filter { $0.status == "approved" }.count; following = outgoing.count; relationship = incoming.first { $0.follower_id == me }?.status
            isMutual = relationship == "approved" && outgoing.contains { $0.following_id == me }
        } catch { self.error = error.localizedDescription }
    }
}
