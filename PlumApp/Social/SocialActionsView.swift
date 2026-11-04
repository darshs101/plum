import Supabase

import SwiftUI

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
    @State private var rows: [LiveNotification] = []
    @State private var actors: [UUID: LiveProfile] = [:]
    @State private var pending: Set<UUID> = []
    @State private var requestDates: [UUID: Date] = [:]
    @State private var handled: [UUID: String] = [:]
    @State private var error: String?
    @State private var loading = true
    @State private var canLoadMore = false
    @State private var working: UUID?
    var body: some View {
        List {
            if loading && rows.isEmpty { ProgressView("Loading notifications…") }
            if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
            if !loading && error == nil && rows.isEmpty { ContentUnavailableView("You’re all caught up", systemImage: "bell", description: Text("Likes, comments, and follow activity will appear here.")) }
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: 12) {
                    ProfileAvatar(path: row.actor_id.flatMap { actors[$0]?.avatar_path }, name: row.actor_id.flatMap { actors[$0]?.display_name } ?? "", size: 44)
                    VStack(alignment: .leading, spacing: 8) {
                        if let postID = row.post_id { NavigationLink { PostDetailView(id: postID) } label: { notificationText(row) }.buttonStyle(.plain) }
                    else if let actorID = row.actor_id { NavigationLink { MemberProfileView(id: actorID, notificationIdentity: actors[actorID]) } label: { notificationText(row) }.buttonStyle(.plain) }
                        else { notificationText(row) }
                        if row.kind == "follow_request", let actor = row.actor_id, pending.contains(actor), requestDates[actor].map({ row.created_at >= $0 }) ?? true {
                            HStack {
                                Button("Confirm") { respond(actor, notificationID: row.id, approve: true) }.buttonStyle(.borderedProminent).tint(.plum)
                                Button("Delete") { respond(actor, notificationID: row.id, approve: false) }.buttonStyle(.bordered)
                            }.disabled(working != nil)
                        }
                    }
                    Spacer(minLength: 0)
                }.padding(.vertical, 6)
            }
            if canLoadMore { Button("Load more notifications") { Task { await load(more: true) } }.disabled(loading) }
        }.listStyle(.plain).navigationTitle("Notifications").task { await load() }.refreshable { await load() }
    }
    private func notificationText(_ row: LiveNotification) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            (Text(row.actor_id.flatMap { actors[$0]?.username }.map { "@\($0) " } ?? "Someone ").fontWeight(.semibold) + Text(copy(row))).foregroundStyle(.primary)
            Text(row.created_at, style: .relative).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func copy(_ row: LiveNotification) -> String {
        if row.kind == "follow_request", let result = handled[row.id] { return result }
        switch row.kind {
        case "like": return "liked your tasting."
        case "comment": return "commented on your tasting."
        case "reply": return "replied to your comment."
        case "follow": return "started following you."
        case "follow_request": return "requested to follow you."
        case "follow_approval": return "accepted your follow request."
        default: return "shared new activity."
        }
    }
    private func respond(_ actor: UUID, notificationID: UUID, approve: Bool) {
        guard working == nil else { return }; working = actor
        Task { defer { working = nil }; do {
            let me = try await PlumAPI.userID()
            if approve { _ = try await PlumAPI.client.from("follows").update(["status":"approved"]).eq("follower_id", value: actor).eq("following_id", value: me).eq("status", value: "requested").execute() }
            else { try await PlumAPI.unfollow(follower: actor, following: me) }
            pending.remove(actor); handled[notificationID] = approve ? "is now following you." : "had their follow request deleted."
        } catch { self.error = error.localizedDescription } }
    }
    private func load(more: Bool = false) async {
        guard !more || !loading else { return }; loading = true; error = nil; defer { loading = false }
        do {
            let me = try await PlumAPI.userID()
            let people: [LiveProfile] = try await PlumAPI.client.rpc("notification_actor_profiles").execute().value
            actors = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
            let requests: [LiveFollow] = try await PlumAPI.client.from("follows").select().eq("following_id", value: me).eq("status", value: "requested").execute().value
            pending = Set(requests.map(\.follower_id))
            requestDates = Dictionary(uniqueKeysWithValues: requests.compactMap { request in request.created_at.map { (request.follower_id, $0) } })
            let offset = more ? rows.count : 0
            let next: [LiveNotification] = try await PlumAPI.client.from("notifications").select().order("created_at", ascending: false).order("id").range(from: offset, to: offset + 99).execute().value
            rows = more ? rows + next : next; canLoadMore = next.count == 100
            let unread = next.filter { $0.read_at == nil }.map(\.id)
            if !unread.isEmpty { _ = try await PlumAPI.client.from("notifications").update(["read_at":ISO8601DateFormatter().string(from: .now)]).in("id", values: unread).execute() }
        } catch { self.error = error.localizedDescription }
    }
}

struct MessagesInboxView: View {
    @State private var friends: [LiveInboxFriend] = []
    @State private var error: String?
    @State private var loading = true
    @State private var connectionGeneration = 0
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        List {
            if loading && friends.isEmpty { ProgressView("Loading messages…") }
            if let error { Text(error).foregroundStyle(.red); Button("Retry") { connectionGeneration += 1; Task { await load() } } }
            if !loading && error == nil && friends.isEmpty { ContentUnavailableView("Messages with friends", systemImage: "paperplane", description: Text("Follow each other to start a conversation. Your friends will appear here.")) }
            ForEach(friends) { friend in
                NavigationLink { ConversationView(otherUser: friend.id, otherName: friend.display_name) } label: {
                    HStack(spacing: 12) {
                        ProfileAvatar(path: friend.avatar_path, name: friend.display_name, size: 54)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(friend.display_name).fontWeight(.semibold); Spacer(); if let date = friend.last_message_at { Text(date, style: .relative).font(.caption).foregroundStyle(.secondary) } }
                            Text(friend.last_message ?? "Say hello to @\(friend.username)").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }.padding(.vertical, 6)
                }
            }
        }.listStyle(.plain).navigationTitle("Messages").task { await load() }.refreshable { await load() }
            .task(id: connectionGeneration) {
                do {
                    let me = try await PlumAPI.userID()
                    let realtime = try PlumAPI.client.realtimeV2
                    let channel = realtime.channel("inbox-\(me)")
                    defer { Task { await realtime.removeChannel(channel) } }
                    let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "messages")
                    try await channel.subscribeWithError()
                    for await _ in changes { await load() }
                } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
            }
            .onChange(of: scenePhase) { _, phase in if phase == .active { connectionGeneration += 1; Task { await load() } } }
    }
    private func load() async {
        loading = true; error = nil; defer { loading = false }
        do { friends = try await PlumAPI.client.rpc("friends_inbox").execute().value }
        catch { self.error = error.localizedDescription }
    }
}

struct ConversationView: View {
    let otherUser: UUID
    var otherName: String? = nil
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
        }.navigationTitle(otherName ?? "Conversation").navigationBarTitleDisplayMode(.inline)
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
