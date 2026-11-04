import Supabase

import SwiftUI

struct SocialActionsView: View {
    var body: some View {
        List { NavigationLink("Follow requests & followers") { FollowManagementView() }; NavigationLink("Direct messages") { MessagesInboxView() } }.navigationTitle("Connections")
    }
}
struct FollowManagementView: View {
    @State private var follows: [LiveFollow] = []; @State private var outgoing: [LiveFollow] = []; @State private var names: [UUID: String] = [:]; @State private var me: UUID?; @State private var error: String?; @State private var workingID: UUID?
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red) }
            if follows.isEmpty && outgoing.isEmpty { Text("No followers or requests yet.") }
            Section("Requests & followers") { ForEach(follows, id: \.follower_id) { follow in
                VStack(alignment: .leading) {
                    Text(names[follow.follower_id] ?? "Plum member")
                    HStack {
                        if follow.status == "requested" { Button(workingID == follow.follower_id ? "Approving…" : "Approve") { approve(follow) }.buttonStyle(.bordered).disabled(workingID != nil) }
                        Button(follow.status == "requested" ? "Decline" : "Remove follower", role: .destructive) { remove(follow) }.buttonStyle(.bordered).disabled(workingID != nil)
                    }
                }
            } }
            Section("Following") { ForEach(outgoing, id: \.following_id) { follow in
                HStack { Text(names[follow.following_id] ?? "Plum member"); Spacer(); if follow.status == "requested" { Text("Requested").font(.caption).foregroundStyle(.secondary) }; Button(follow.status == "requested" ? "Cancel" : "Unfollow", role: .destructive) { remove(follow) }.buttonStyle(.bordered).disabled(workingID != nil) }
            } }
        }.navigationTitle("Followers & requests").task { await load() }.refreshable { await load() }
    }
    private func load() async { do { let id = try await PlumAPI.userID(); me = id; follows = try await PlumAPI.client.from("follows").select().eq("following_id", value: id).execute().value; outgoing = try await PlumAPI.client.from("follows").select().eq("follower_id", value: id).execute().value; for f in follows { names[f.follower_id] = (try? await PlumAPI.profile(f.follower_id))?.username ?? "Private member" }; for f in outgoing { names[f.following_id] = (try? await PlumAPI.profile(f.following_id))?.username ?? "Private member" } } catch { self.error = error.localizedDescription } }
    private func approve(_ follow: LiveFollow) { workingID = follow.follower_id; error = nil; Task { defer { workingID = nil }; do { _ = try await PlumAPI.client.from("follows").update(["status":"approved"]).eq("follower_id", value: follow.follower_id).eq("following_id", value: follow.following_id).execute(); await load() } catch { self.error = error.localizedDescription } } }
    private func remove(_ follow: LiveFollow) { workingID = follow.follower_id; error = nil; Task { defer { workingID = nil }; do { try await PlumAPI.unfollow(follower: follow.follower_id, following: follow.following_id); await load() } catch { self.error = error.localizedDescription } } }
}
struct LiveNotificationsView: View {
    @State private var rows: [LiveNotification] = []; @State private var actorNames: [UUID: String] = [:]; @State private var error: String?; @State private var loading = true
    var body: some View {
        List {
            NavigationLink("Manage follow requests") { FollowManagementView() }
            if loading { ProgressView() }
            if let error { Text(error).foregroundStyle(.red) }
            if !loading && rows.isEmpty { Text("You’re all caught up.") }
            ForEach(rows) { row in
                VStack(alignment: .leading) {
                    let copy = "\(row.actor_id.flatMap { actorNames[$0] }.map { "@\($0) " } ?? "")\(row.kind.replacingOccurrences(of: "_", with: " ").capitalized)"
                    if let postID = row.post_id { NavigationLink(copy) { PostDetailView(id: postID) } }
                    else if let actorID = row.actor_id { NavigationLink(copy) { MemberProfileView(id: actorID) } }
                    else { Text(copy) }
                    Text(row.created_at, style: .relative).font(.caption).foregroundStyle(.secondary)
                }.fontWeight(row.read_at == nil ? .semibold : .regular)
            }
        }.navigationTitle("Notifications").task { await load() }.refreshable { await load() }
    }
    private func load() async { loading = true; defer { loading = false }; do { rows = try await PlumAPI.client.from("notifications").select().order("created_at", ascending: false).limit(100).execute().value; for actor in Set(rows.compactMap(\.actor_id)) { actorNames[actor] = (try? await PlumAPI.profile(actor))?.username ?? "Plum member" }; let unread = rows.filter { $0.read_at == nil }.map(\.id); if !unread.isEmpty { _ = try await PlumAPI.client.from("notifications").update(["read_at":ISO8601DateFormatter().string(from: .now)]).in("id", values: unread).execute(); let now = Date(); rows = rows.map { var item = $0; if item.read_at == nil { item = LiveNotification(id: item.id, kind: item.kind, actor_id: item.actor_id, post_id: item.post_id, created_at: item.created_at, read_at: now) }; return item } } } catch { self.error = error.localizedDescription } }
}
struct MessagesInboxView: View {
    @State private var rows: [LiveConversation] = []; @State private var me: UUID?; @State private var names: [UUID: String] = [:]; @State private var error: String?; @State private var loading = true
    var body: some View {
        List {
            if loading { ProgressView("Loading messages…") }
            if let error { VStack(alignment: .leading) { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } } }
            if !loading && error == nil && rows.isEmpty { Text("Open a mutual follower’s profile and tap Message to start a conversation.") }
            ForEach(rows) { row in if let other = row.direct_key.split(separator: ":").compactMap({ UUID(uuidString: String($0)) }).first(where: { $0 != me }) { NavigationLink(names[other] ?? "Conversation") { ConversationView(otherUser: other) } } }
        }.navigationTitle("Messages").task { await load() }.refreshable { await load() }
    }
    private func load() async { loading = true; error = nil; defer { loading = false }; do { me = try await PlumAPI.userID(); rows = try await PlumAPI.client.from("conversations").select().order("created_at", ascending: false).execute().value; names = [:]; for row in rows { for id in row.direct_key.split(separator: ":").compactMap({ UUID(uuidString: String($0)) }) where id != me { names[id] = try await PlumAPI.profile(id).username } } } catch { self.error = error.localizedDescription } }
}
struct ConversationView: View {
    let otherUser: UUID
    var sharedPost: UUID? = nil
    @State private var conversation: UUID?
    @State private var messages: [LiveMessage] = []
    @State private var text = ""
    @State private var error: String?
    @State private var working = false
    @State private var me: UUID?
    @State private var shared = false
    @State private var reconnecting = false
    @State private var connectionGeneration = 0
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack {
            if let error { VStack(alignment: .leading) { Text(error).foregroundStyle(.red); Button(reconnecting ? "Reconnecting…" : "Reconnect") { reconnect() }.disabled(reconnecting) }.padding() }
            ScrollView { LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(messages) { message in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(message.sender_id == me ? "You" : "Member").font(.caption).foregroundStyle(.secondary)
                        if let body = message.body { Text(body) }
                        if let share = message.post_shares { NavigationLink("Open shared tasting") { PostDetailView(id: share.post_id) } }
                    }.padding(12).background(message.sender_id == me ? Color.plum.opacity(0.1) : Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
            }.padding() }
            if sharedPost != nil && !shared { Button("Share this tasting") { send(share: true) }.buttonStyle(.bordered).disabled(conversation == nil || working) }
            HStack { TextField("Message", text: $text).textFieldStyle(.roundedBorder).accessibilityIdentifier("dm.message"); Button("Send") { send(share: false) }.accessibilityIdentifier("dm.send").disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conversation == nil || working) }.padding()
        }.navigationTitle("Conversation").navigationBarTitleDisplayMode(.inline)
            .task {
                do { me = try await PlumAPI.userID(); conversation = try await PlumAPI.client.rpc("start_direct_conversation", params: ["other_user":otherUser.uuidString]).execute().value; await load() }
                catch { self.error = error.localizedDescription }
            }
            .task(id: "\(conversation?.uuidString ?? "none")-\(connectionGeneration)") {
                guard let conversation else { return }
                do {
                    let realtime = try PlumAPI.client.realtimeV2
                    let channel = realtime.channel("messages-\(conversation)")
                    defer { Task { await realtime.removeChannel(channel) } }
                    let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "messages", filter: "conversation_id=eq.\(conversation.uuidString)")
                    try await channel.subscribeWithError()
                    for await _ in changes { await load() }
                } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
            }
            .onChange(of: scenePhase) { _, phase in if phase == .active, conversation != nil { Task { await load(); connectionGeneration += 1 } } }
    }
    private func load() async { guard let conversation else { return }; do { messages = try await PlumAPI.client.from("messages").select("*,post_shares(post_id)").eq("conversation_id", value: conversation).order("created_at").execute().value } catch { self.error = error.localizedDescription } }
    private func send(share: Bool) {
        guard let conversation else { return }; working = true
        Task { defer { working = false }; do {
            struct Send: Encodable { let conversation_id: UUID; let body: String?; let post_id: UUID? }
            _ = try await PlumAPI.client.rpc("send_message_with_share", params: Send(conversation_id: conversation, body: share ? "Shared a tasting" : text.trimmingCharacters(in: .whitespacesAndNewlines), post_id: share ? sharedPost : nil)).execute()
            if share { shared = true }
            text = ""; await load()
        } catch { self.error = error.localizedDescription } }
    }
    private func reconnect() { reconnecting = true; error = nil; Task { defer { reconnecting = false }; do { me = try await PlumAPI.userID(); conversation = try await PlumAPI.client.rpc("start_direct_conversation", params: ["other_user":otherUser.uuidString]).execute().value; await load(); connectionGeneration += 1 } catch { self.error = error.localizedDescription } } }
}
struct SharePostView: View {
    let postID: UUID
    @State private var profiles: [LiveProfile] = []; @State private var error: String?
    var body: some View {
        NavigationStack { List {
            if let error { Text(error).foregroundStyle(.red) }
            if profiles.isEmpty { Text("Post sharing is available between mutual followers. Follow each other first.") }
            ForEach(profiles) { p in NavigationLink("@\(p.username)") { ConversationView(otherUser: p.id, sharedPost: postID) } }
        }.navigationTitle("Share with a friend").task {
            do { profiles = []; let me = try await PlumAPI.userID(); let incoming: [LiveFollow] = try await PlumAPI.client.from("follows").select().eq("following_id", value: me).eq("status", value: "approved").execute().value; let outgoing: [LiveFollow] = try await PlumAPI.client.from("follows").select().eq("follower_id", value: me).eq("status", value: "approved").execute().value
                let ids = Set(incoming.map(\.follower_id)).intersection(outgoing.map(\.following_id)); for id in ids { profiles.append(try await PlumAPI.profile(id)) }
            } catch { self.error = error.localizedDescription }
        } }
    }
}
