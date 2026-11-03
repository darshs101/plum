import SwiftUI

/// Entry points for v1 social actions. Server enforcement—not this UI—decides visibility,
/// mutual-follow eligibility for messages/mentions, and comment deletion rights. The live
/// adapter starts a thread only through `start_direct_conversation(other_user)`; it must never
/// insert a conversation or member row directly from the client.
struct SocialActionsView: View {
    @State private var showingReport = false
    var body: some View { List {
        Section("FOLLOWING") { NavigationLink("Follow requests") { ContentUnavailableView("No requests", systemImage: "person.badge.clock") }; NavigationLink("Followers") { ContentUnavailableView("Manage followers", systemImage: "person.2") } }
        Section {
            NavigationLink("Direct messages") {
                ContentUnavailableView("Messages are between mutual followers", systemImage: "message")
            }
        } header: {
            Text("MESSAGES")
        } footer: {
            Text("One-to-one text and Plum post shares only. Photo and group messages are not part of v1.")
        }
        Section("SAFETY") { Button("Report post, account, or photo", role: .destructive) { showingReport = true } }
    }.navigationTitle("Social").sheet(isPresented: $showingReport) { ReportSheet() } }
}

private struct ReportSheet: View {
    @Environment(\.dismiss) private var dismiss; @State private var reason = ""
    var body: some View { NavigationStack { Form { Section("What needs review?") { Picker("Content", selection: .constant("Post")) { Text("Post").tag("Post"); Text("Account").tag("Account"); Text("Photo").tag("Photo") }; TextField("Tell us what happened", text: $reason, axis: .vertical) }; Section { Button("Submit report") { dismiss() }.disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }.navigationTitle("Report").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } } } }
}
