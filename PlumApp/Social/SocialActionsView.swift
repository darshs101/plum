import Supabase

import SwiftUI

struct SocialActionsView: View {
    var body: some View {
        List { NavigationLink("Follow requests & followers") { FollowManagementView() }; NavigationLink("Direct messages") { MessagesInboxView() } }.navigationTitle("Connections")
    }
}
struct FollowManagementView: View {
    @State private var follows: [LiveFollow] = []; @State private var names: [UUID: String] = [:]; @State private var me: UUID?; @State private var error: String?
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red) }
            if follows.isEmpty { Text("No followers or requests yet.") }
            ForEach(follows, id: \.follower_id) { follow in
                VStack(alignment: .leading) {
                    Text(names[follow.follower_id] ?? "Plum member")
                    HStack {
                        if follow.status == "requested" { Button("Approve") { Task { do { _ = try await PlumAPI.client.from("follows").update(["status":"approved"]).eq("follower_id", value: follow.follower_id).eq("following_id", value: follow.following_id).execute(); await load() } catch { self.error = error.localizedDescription } } }.buttonStyle(.bordered) }
                        Button(follow.status == "requested" ? "Decline" : "Remove follower", role: .destructive) { Task { do { try await PlumAPI.unfollow(follower: follow.follower_id, following: follow.following_id); await load() } catch { self.error = error.localizedDescription } } }.buttonStyle(.bordered)
                    }
                }
            }
        }.navigationTitle("Followers & requests").task { await load() }.refreshable { await load() }
    }
    private func load() async { do { let id = try await PlumAPI.userID(); me = id; follows = try await PlumAPI.client.from("follows").select().eq("following_id", value: id).execute().value; for f in follows { names[f.follower_id] = (try? await PlumAPI.profile(f.follower_id))?.username ?? "Private member" } } catch { self.error = error.localizedDescription } }
}
struct LiveNotificationsView: View {
    @State private var rows: [LiveNotification] = []; @State private var error: String?; @State private var loading = true
    var body: some View {
        List {
            NavigationLink("Manage follow requests") { FollowManagementView() }
            if loading { ProgressView() }
            if let error { Text(error).foregroundStyle(.red) }
            if !loading && rows.isEmpty { Text("You’re all caught up.") }
            ForEach(rows) { row in
                VStack(alignment: .leading) {
                    if let postID = row.post_id { NavigationLink(row.kind.replacingOccurrences(of: "_", with: " ").capitalized) { PostDetailView(id: postID) } }
                    else if let actorID = row.actor_id { NavigationLink(row.kind.replacingOccurrences(of: "_", with: " ").capitalized) { MemberProfileView(id: actorID) } }
                    Text(row.created_at, style: .relative).font(.caption).foregroundStyle(.secondary)
                }
            }
        }.navigationTitle("Notifications").task { await load() }.refreshable { await load() }
    }
    private func load() async { loading = true; defer { loading = false }; do { rows = try await PlumAPI.client.from("notifications").select().order("created_at", ascending: false).limit(100).execute().value; let unread = rows.filter { $0.read_at == nil }.map(\.id); if !unread.isEmpty { _ = try await PlumAPI.client.from("notifications").update(["read_at":ISO8601DateFormatter().string(from: .now)]).in("id", values: unread).execute() } } catch { self.error = error.localizedDescription } }
}
struct MessagesInboxView: View {
    @State private var rows: [LiveConversation] = []; @State private var me: UUID?; @State private var names: [UUID: String] = [:]; @State private var error: String?
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red) }
            if rows.isEmpty { Text("Open a mutual follower’s profile and tap Message to start a conversation.") }
            ForEach(rows) { row in if let other = row.direct_key.split(separator: ":").compactMap({ UUID(uuidString: String($0)) }).first(where: { $0 != me }) { NavigationLink(names[other] ?? "Conversation") { ConversationView(otherUser: other) } } }
        }.navigationTitle("Messages").task { do { me = try await PlumAPI.userID(); rows = try await PlumAPI.client.from("conversations").select().order("created_at", ascending: false).execute().value; for row in rows { for id in row.direct_key.split(separator: ":").compactMap({ UUID(uuidString: String($0)) }) where id != me { names[id] = try await PlumAPI.profile(id).username } } } catch { self.error = error.localizedDescription } }
    }
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
    var body: some View {
        VStack {
            if let error { Text(error).foregroundStyle(.red).padding() }
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
            HStack { TextField("Message", text: $text).textFieldStyle(.roundedBorder); Button("Send") { send(share: false) }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conversation == nil || working) }.padding()
        }.navigationTitle("Conversation").navigationBarTitleDisplayMode(.inline)
            .task {
                do { me = try await PlumAPI.userID(); conversation = try await PlumAPI.client.rpc("start_direct_conversation", params: ["other_user":otherUser.uuidString]).execute().value; await load() }
                catch { self.error = error.localizedDescription }
            }
            .task(id: conversation) {
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
    }
    private func load() async { guard let conversation else { return }; do { messages = try await PlumAPI.client.from("messages").select("*,post_shares(post_id)").eq("conversation_id", value: conversation).order("created_at").execute().value } catch { self.error = error.localizedDescription } }
    private func send(share: Bool) {
        guard let conversation, let me else { return }; working = true
        Task { defer { working = false }; do {
            struct New: Encodable { let conversation_id: UUID; let sender_id: UUID; let body: String? }
            struct Created: Decodable { let id: UUID }
            let row: Created = try await PlumAPI.client.from("messages").insert(New(conversation_id: conversation, sender_id: me, body: share ? "Shared a tasting" : text)).select("id").single().execute().value
            if share, let sharedPost { _ = try await PlumAPI.client.from("post_shares").insert(["message_id":row.id.uuidString,"post_id":sharedPost.uuidString]).execute(); shared = true }
            text = ""; await load()
        } catch { self.error = error.localizedDescription } }
    }
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
            do { let me = try await PlumAPI.userID(); let incoming: [LiveFollow] = try await PlumAPI.client.from("follows").select().eq("following_id", value: me).eq("status", value: "approved").execute().value; let outgoing: [LiveFollow] = try await PlumAPI.client.from("follows").select().eq("follower_id", value: me).eq("status", value: "approved").execute().value
                let ids = Set(incoming.map(\.follower_id)).intersection(outgoing.map(\.following_id)); for id in ids { profiles.append(try await PlumAPI.profile(id)) }
            } catch { self.error = error.localizedDescription }
        } }
    }
}
