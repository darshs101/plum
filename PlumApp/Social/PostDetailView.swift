import SwiftUI

struct PostDetailView: View {
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var post: LivePost?
    @State private var comments: [LiveComment] = []
    @State private var likes = 0
    @State private var liked = false
    @State private var me: UUID?
    @State private var bodyText = ""
    @State private var replyTo: LiveComment?
    @State private var error: String?
    @State private var loading = true
    @State private var working = false
    @State private var reporting = false
    @State private var saving = false
    @State private var editing = false
    @State private var sharing = false
    @State private var deleting = false
    @State private var reportedPhoto: LivePhoto?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if loading { ProgressView("Loading post…") }
                if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
                if let post {
                    LivePostCard(post: post)
                    HStack(spacing: 22) {
                        Button { action { try await PlumServices.social.setLike(postID: id, isLiked: !liked); liked.toggle(); likes += liked ? 1 : -1 } } label: { Label("\(likes)", systemImage: liked ? "heart.fill" : "heart") }
                        Button { saving = true } label: { Image(systemName: "bookmark") }.accessibilityLabel("Add to collection")
                        Button { sharing = true } label: { Image(systemName: "paperplane") }.accessibilityLabel("Share in message")
                        Spacer()
                        Menu {
                            ForEach(Array(post.post_photos.enumerated()), id: \.element.id) { index, photo in Button("Report photo \(index + 1)") { reportedPhoto = photo } }
                            Button("Report post", role: .destructive) { reporting = true }
                            if me == post.author_id { Button("Edit post") { editing = true }; Button("Delete post", role: .destructive) { deleting = true } }
                        } label: { Image(systemName: "ellipsis") }
                    }.disabled(working)
                    Text("Comments").font(.headline)
                    ForEach(comments) { comment in commentRow(comment, post: post) }
                    if comments.isEmpty { Text("Start the conversation.").foregroundStyle(.secondary) }
                    if let replyTo { HStack { Text("Replying to @\(replyTo.profiles?.username ?? "member")").font(.caption); Button("Cancel") { self.replyTo = nil } } }
                    TextField("Add a comment", text: $bodyText, axis: .vertical).textFieldStyle(.roundedBorder)
                    Button("Send comment") { action {
                        guard let me else { return }
                        struct NewComment: Encodable { let post_id: UUID; let author_id: UUID; let body: String; let parent_id: UUID? }
                        _ = try await PlumAPI.client.from("comments").insert(NewComment(post_id: id, author_id: me, body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines), parent_id: replyTo?.id)).execute()
                        bodyText = ""; replyTo = nil; await load()
                    } }.disabled(working || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(18)
        }.navigationTitle("Tasting").navigationBarTitleDisplayMode(.inline).task { await load() }.refreshable { await load() }
            .sheet(item: $reportedPhoto) { photo in ReportContentView(type: "photo", id: photo.id) }
            .sheet(isPresented: $reporting) { ReportContentView(type: "post", id: id) }
            .sheet(isPresented: $saving) { AddToCollectionView(postID: id) }
            .sheet(isPresented: $sharing) { SharePostView(postID: id) }
            .sheet(isPresented: $editing, onDismiss: { Task { await load() } }) { if let post { EditPostView(post: post) } }
            .confirmationDialog("Delete this post and its ratings?", isPresented: $deleting) { Button("Delete post", role: .destructive) { action { try await PlumAPI.removePost(id); dismiss() } } }
    }
    private func commentRow(_ comment: LiveComment, post: LivePost) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("@\(comment.profiles?.username ?? "member")").font(.caption.bold())
            if comment.parent_id != nil { Label("Reply", systemImage: "arrow.turn.down.right").font(.caption).foregroundStyle(.secondary) }
            Text(comment.body)
            HStack { Button("Reply") { replyTo = comment }; if me == comment.author_id || me == post.author_id { Button("Delete", role: .destructive) { action { _ = try await PlumAPI.client.from("comments").delete().eq("id", value: comment.id).execute(); await load() } } } }.font(.caption)
            Divider()
        }
    }
    private func action(_ task: @escaping @MainActor () async throws -> Void) { guard !working else { return }; working = true; error = nil; Task { defer { working = false }; do { try await task() } catch { self.error = error.localizedDescription } } }
    private func load() async {
        loading = true; error = nil; defer { loading = false }
        do {
            me = try await PlumAPI.userID(); post = try await PlumAPI.posts(id: id).first
            if post == nil { throw SocialClientError.permissionDenied }
            comments = try await PlumAPI.client.from("comments").select("*,profiles!comments_author_id_fkey(username)").eq("post_id", value: id).order("created_at").execute().value
            struct Like: Decodable { let user_id: UUID }
            let rows: [Like] = try await PlumAPI.client.from("likes").select("user_id").eq("post_id", value: id).execute().value
            likes = rows.count; liked = rows.contains { $0.user_id == me }
        } catch { self.error = error.localizedDescription }
    }
}

struct ReportContentView: View {
    let type: String; let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""; @State private var error: String?; @State private var working = false; @State private var sent = false
    var body: some View {
        NavigationStack { Form {
            if sent { Label("Report received for review", systemImage: "checkmark.circle") }
            else { TextField("What happened?", text: $reason, axis: .vertical); if let error { Text(error).foregroundStyle(.red) }; Button("Submit report") { working = true; Task { defer { working = false }; do { try await PlumAPI.report(type: type, id: id, reason: reason); sent = true } catch { self.error = error.localizedDescription } } }.disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working) }
        }.navigationTitle("Report \(type)").toolbar { Button("Done") { dismiss() } } }
    }
}
