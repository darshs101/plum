import SwiftUI

struct PostDetailView: View {
    let id: UUID
    var embedded = false
    var onDeleted: (() -> Void)? = nil
    private var reloadToken = 0
    @Environment(\.dismiss) private var dismiss
    @State private var post: LivePost?
    @State private var comments: [LiveComment] = []
    @State private var expandedComments: Set<UUID> = []
    @State private var likes = 0
    @State private var liked = false
    @State private var me: UUID?
    @State private var bodyText = ""
    @State private var replyTo: LiveComment?
    @FocusState private var commentFocused: Bool
    @State private var error: String?
    @State private var loading = true
    @State private var working = false
    @State private var reporting = false
    @State private var saving = false
    @State private var editing = false
    @State private var sharing = false
    @State private var deleting = false
    init(id: UUID, embedded: Bool = false, onDeleted: (() -> Void)? = nil, initialPost: LivePost? = nil, reloadToken: Int = 0) {
        self.id = id; self.embedded = embedded; self.onDeleted = onDeleted
        self.reloadToken = reloadToken
        _post = State(initialValue: initialPost)
        _loading = State(initialValue: initialPost == nil)
    }
    @ViewBuilder var body: some View {
        if embedded { content }
        else {
            ScrollView { content }.navigationTitle("Tasting").navigationBarTitleDisplayMode(.inline).refreshable { await load() }
        }
    }
    private var content: some View {
            VStack(alignment: .leading, spacing: 18) {
                if loading && post == nil { ProgressView("Loading post…") }
                if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
                if let post {
                    LivePostContent(post: post)
                    HStack(spacing: 22) {
                        Button { action { try await PlumServices.social.setLike(postID: id, isLiked: !liked); liked.toggle(); likes += liked ? 1 : -1 } } label: { Label("\(likes)", systemImage: liked ? "heart.fill" : "heart") }.accessibilityIdentifier("post.like")
                        Button { saving = true } label: { Image(systemName: "bookmark") }.accessibilityLabel("Add to collection").accessibilityIdentifier("post.actions")
                        Button { sharing = true } label: { Image(systemName: "paperplane") }.accessibilityLabel("Share in message")
                        Spacer()
                        Menu {
                            Button("Report post", role: .destructive) { reporting = true }
                            if me == post.author_id { Button("Edit post") { editing = true }; Button("Delete post", role: .destructive) { deleting = true } }
                        } label: { Image(systemName: "ellipsis") }.accessibilityLabel("Post options").accessibilityIdentifier("post.options")
                    }.disabled(working)
                    Text("Comments").font(.headline)
                    let ids = Set(comments.map(\.id))
                    let children = repliesByParent
                    ForEach(comments.filter { $0.parent_id.map { !ids.contains($0) } ?? true }) { comment in
                        CommentThreadRow(comment: comment, children: children, expanded: $expandedComments, me: me, postOwner: post.author_id, working: working, onReply: { replyTo = $0; commentFocused = true }, onDelete: { comment in
                            action { _ = try await PlumAPI.client.from("comments").delete().eq("id", value: comment.id).execute(); await load() }
                        })
                        Divider()
                    }
                    if comments.isEmpty { Text("Start the conversation.").foregroundStyle(.secondary) }
                    if let replyTo { HStack { Text("Replying to @\(replyTo.profiles?.username ?? "member")").font(.caption); Button("Cancel") { self.replyTo = nil } } }
                    TextField("Add a comment", text: $bodyText, axis: .vertical).textFieldStyle(.roundedBorder).accessibilityIdentifier("post.comment").focused($commentFocused).disabled(working)
                    Button("Send comment") { action {
                        guard let me else { return }
                        struct NewComment: Encodable { let post_id: UUID; let author_id: UUID; let body: String; let parent_id: UUID? }
                        let parent = replyTo?.id
                        _ = try await PlumAPI.client.from("comments").insert(NewComment(post_id: id, author_id: me, body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines), parent_id: parent)).execute()
                        if let parent { expandedComments.insert(parent) }
                        bodyText = ""; replyTo = nil; await load()
                    } }.accessibilityIdentifier("post.sendComment").disabled(working || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(18)
            .task(id: reloadToken) { await load() }
            .sheet(isPresented: $reporting) { ReportContentView(type: "post", id: id) }
            .sheet(isPresented: $saving) { AddToCollectionView(postID: id) }
            .sheet(isPresented: $sharing) { SharePostView(postID: id) }
            .sheet(isPresented: $editing, onDismiss: { Task { await load() } }) { if let post { EditPostView(post: post) } }
            .confirmationDialog("Delete this post and its ratings?", isPresented: $deleting) { Button("Delete post", role: .destructive) { action { try await PlumAPI.removePost(id); if let onDeleted { onDeleted() } else { dismiss() } } } }
    }
    private var repliesByParent: [UUID: [LiveComment]] {
        comments.reduce(into: [:]) { groups, comment in
            if let parent = comment.parent_id { groups[parent, default: []].append(comment) }
        }
    }
    private func action(_ task: @escaping @MainActor () async throws -> Void) { guard !working else { return }; working = true; error = nil; Task { defer { working = false }; do { try await task() } catch { self.error = error.localizedDescription } } }
    private func load() async {
        loading = true; error = nil; defer { loading = false }
        do {
            me = try await PlumAPI.userID(); post = try await PlumAPI.posts(id: id).first
            if post == nil { throw SocialClientError.permissionDenied }
            comments = try await PlumAPI.client.from("comments").select("*,profiles!comments_author_id_fkey(username)").eq("post_id", value: id).order("created_at").order("id").execute().value
            let commentIDs = Set(comments.map(\.id)); expandedComments.formIntersection(commentIDs)
            if let replyTo, !commentIDs.contains(replyTo.id) { self.replyTo = nil }
            struct Like: Decodable { let user_id: UUID }
            let rows: [Like] = try await PlumAPI.client.from("likes").select("user_id").eq("post_id", value: id).execute().value
            likes = rows.count; liked = rows.contains { $0.user_id == me }
        } catch { self.error = error.localizedDescription }
    }
}

private struct CommentThreadRow: View {
    let comment: LiveComment
    let children: [UUID: [LiveComment]]
    @Binding var expanded: Set<UUID>
    let me: UUID?
    let postOwner: UUID
    let working: Bool
    let onReply: (LiveComment) -> Void
    let onDelete: (LiveComment) -> Void
    var depth = 0
    private var replies: [LiveComment] { children[comment.id] ?? [] }
    private var isExpanded: Bool { expanded.contains(comment.id) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("@\(comment.profiles?.username ?? "member")").font(.caption.bold())
            Text(comment.body)
            HStack {
                Button("Reply") { onReply(comment) }.accessibilityIdentifier("comment.reply.\(comment.id.uuidString)")
                if me == comment.author_id || me == postOwner {
                    Button("Delete", role: .destructive) { onDelete(comment) }.accessibilityIdentifier("comment.delete.\(comment.id.uuidString)")
                }
            }.font(.caption).disabled(working)
            if !replies.isEmpty {
                Button {
                    if isExpanded { expanded.remove(comment.id) } else { expanded.insert(comment.id) }
                } label: {
                    Label(isExpanded ? "Hide replies" : "Show replies", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                }.font(.caption.weight(.semibold)).foregroundStyle(.plum)
                    .accessibilityIdentifier("comment.replies.\(comment.id.uuidString)")
                    .accessibilityValue("\(replies.count) replies, \(isExpanded ? "expanded" : "collapsed")")
                if isExpanded {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(replies) { reply in
                            CommentThreadRow(comment: reply, children: children, expanded: $expanded, me: me, postOwner: postOwner, working: working, onReply: onReply, onDelete: onDelete, depth: depth + 1)
                        }
                    }.padding(.leading, depth < 3 ? 16 : 0)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReportContentView: View {
    let type: String; let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""; @State private var error: String?; @State private var working = false; @State private var sent = false
    var body: some View {
        NavigationStack { Form {
            if sent { Label("Report received for review", systemImage: "checkmark.circle") }
            else { TextField("What happened?", text: $reason, axis: .vertical).accessibilityIdentifier("report.reason"); if let error { Text(error).foregroundStyle(.red) }; Button("Submit report") { working = true; Task { defer { working = false }; do { try await PlumAPI.report(type: type, id: id, reason: reason); sent = true } catch { self.error = error.localizedDescription } } }.accessibilityIdentifier("report.submit").disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working) }
        }.navigationTitle("Report \(type)").toolbar { Button("Done") { dismiss() } } }
    }
}
