import SwiftUI

struct ProfileView: View { var body: some View { NavigationStack { MemberProfileView(id: nil) } } }
struct MemberProfileView: View {
    let id: UUID?
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
    @State private var error: String?
    @State private var loading = true
    @State private var working = false
    @State private var editing = false
    @State private var reporting = false
    @State private var newCollection = false
    @State private var displayName = ""
    @State private var username = ""
    @State private var city = ""
    @State private var privateAccount = false
    @State private var isAdmin = false
    @State private var notificationMessage: String?
    private var canViewContent: Bool { isOwner || profile?.visibility == "public" || relationship == "approved" }
    private var isOwner: Bool { id == nil || id == me }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if loading { ProgressView("Loading profile…") }
                if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
                if let profile {
                    profileHeader(profile)
                    if isOwner {
                        HStack { Button("Edit profile") { editing = true }; Spacer(); NavigationLink("Connections & messages") { SocialActionsView() } }.font(.subheadline)
                    } else {
                        HStack {
                            Button(relationship == nil ? "Follow" : relationship == "requested" ? "Cancel request" : "Unfollow") { perform {
                                guard let me else { return }
                                if relationship == nil { try await PlumAPI.follow(profile.id, status: profile.visibility == "private" ? "requested" : "approved") }
                                else { try await PlumAPI.unfollow(follower: me, following: profile.id) }; await load()
                            } }.buttonStyle(.bordered).disabled(working)
                            NavigationLink("Message") { ConversationView(otherUser: profile.id) }
                            Button("Report") { reporting = true }
                        }
                    }
                    if canViewContent {
                    Text("PHOTO DIARY").font(.caption.bold()).foregroundStyle(.plum)
                    if posts.isEmpty { Text("No tastings yet.").foregroundStyle(.secondary) }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                        ForEach(posts) { post in NavigationLink { PostDetailView(id: post.id) } label: { AsyncImage(url: post.post_photos.first?.url) { $0.resizable().scaledToFill() } placeholder: { Color.plum.opacity(0.12) }.frame(height: 115).clipped().accessibilityLabel(post.restaurants?.name ?? "Open tasting") } }
                    }
                    if canLoadMore { Button("Load more tastings") { perform { let more = try await PlumAPI.posts(author: profile.id, offset: posts.count); posts += more; canLoadMore = more.count == 30 } } }
                    HStack { Text("COLLECTIONS & RANKINGS").font(.caption.bold()).foregroundStyle(.plum); Spacer(); if isOwner { Button { newCollection = true } label: { Image(systemName: "plus.circle") }.accessibilityLabel("Create collection") } }
                    ForEach(collections) { collection in NavigationLink { CollectionDetailView(id: collection.id) } label: { HStack { Image(systemName: collection.kind == "ranked" ? "list.number" : "bookmark"); Text(collection.title); Spacer(); if !collection.is_public { Image(systemName: "lock") } }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 14)) } }
                    } else { Text("Only approved followers can view this private profile’s posts and collections.").foregroundStyle(.secondary) }
                    if isOwner {
                        Button("Enable notifications") { perform { let allowed = try await NotificationRegistration.request(); notificationMessage = allowed ? "Notifications enabled. Delivery requires a supported device." : "Notifications are off. You can enable them in iOS Settings." } }
                        if let notificationMessage { Text(notificationMessage).font(.caption).foregroundStyle(.secondary) }
                        if isAdmin { NavigationLink("Moderation console") { AdminConsoleView() } }
                    }
                    if isOwner { Button("Sign out", role: .destructive) { Task { await session.signOut() } }.padding(.top, 20) }
                }
            }.padding(20)
        }.navigationTitle(isOwner ? "Profile" : profile?.username ?? "Profile").navigationBarTitleDisplayMode(.inline)
            .background(PlumStyle.cream.ignoresSafeArea()).task { await load() }.refreshable { await load() }
            .toolbar { if isOwner { ToolbarItem(placement: .topBarTrailing) { NavigationLink { LiveNotificationsView() } label: { Image(systemName: "bell") }.accessibilityLabel("Notifications") } } }
            .sheet(isPresented: $editing) { editSheet }
            .sheet(isPresented: $newCollection, onDismiss: { Task { await load() } }) { NewCollectionView() }
            .sheet(isPresented: $reporting) { if let profile { ReportContentView(type: "account", id: profile.id) } }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("plumPushStatus"))) { note in notificationMessage = note.object as? String }
    }
    private func profileHeader(_ p: LiveProfile) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill").font(.system(size: 70)).foregroundStyle(.plum)
            Text(p.display_name).font(.title.bold()); Text("@\(p.username)").foregroundStyle(.secondary)
            if let city = p.city { Text(city).font(.subheadline) }
            if p.visibility == "private" { Label("Private account", systemImage: "lock").font(.caption) }
            if canViewContent { HStack { Text("\(postCount) posts"); Spacer(); Text("\(followers) followers"); Spacer(); Text("\(following) following") }.font(.caption) }
        }.frame(maxWidth: .infinity)
    }
    private var editSheet: some View {
        NavigationStack { Form {
            TextField("Display name", text: $displayName)
            TextField("Username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("City", text: $city)
            Toggle("Private account", isOn: $privateAccount)
            Text("Private posts, photos, collections, and ratings are excluded from public discovery. Followers require approval.").font(.caption)
            if let error { Text(error).foregroundStyle(.red) }
            Button("Save changes") { perform {
                guard let me else { return }
                _ = try await PlumAPI.client.from("profiles").update(["display_name":displayName,"username":username.lowercased(),"city":city,"visibility":privateAccount ? "private" : "public"]).eq("id", value: me).execute()
                editing = false; await load()
            } }.disabled(working || displayName.isEmpty || username.range(of: "^[a-z0-9_]{3,30}$", options: .regularExpression) == nil)
        }.navigationTitle("Edit profile").toolbar { Button("Cancel") { editing = false } } }
    }
    private func perform(_ operation: @escaping @MainActor () async throws -> Void) { working = true; error = nil; Task { defer { working = false }; do { try await operation() } catch { self.error = error.localizedDescription } } }
    private func load() async {
        loading = true; error = nil; defer { loading = false }
        do {
            isAdmin = try await PlumAPI.client.auth.session.user.appMetadata["plum_role"] == .string("admin")
            let me = try await PlumAPI.userID(); self.me = me; let target = id ?? me
            profile = try await PlumAPI.profile(target)
            posts = try await PlumAPI.posts(author: target); canLoadMore = posts.count == 30
            postCount = try await PlumAPI.client.from("posts").select("id", head: true, count: .exact).eq("author_id", value: target).eq("is_removed", value: false).execute().count ?? 0
            collections = try await PlumAPI.collections(owner: target)
            let incoming: [LiveFollow] = try await PlumAPI.client.from("follows").select().eq("following_id", value: target).execute().value
            let outgoing: [LiveFollow] = try await PlumAPI.client.from("follows").select().eq("follower_id", value: target).eq("status", value: "approved").execute().value
            followers = incoming.filter { $0.status == "approved" }.count; following = outgoing.count; relationship = incoming.first { $0.follower_id == me }?.status
            if let p = profile { displayName = p.display_name; username = p.username; city = p.city ?? ""; privateAccount = p.visibility == "private" }
        } catch { self.error = error.localizedDescription }
    }
}
