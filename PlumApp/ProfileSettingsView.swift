import PhotosUI
import Supabase
import SwiftUI

struct ProfileSettingsView: View {
    let profile: LiveProfile
    let isAdmin: Bool
    var onChanged: () -> Void
    @EnvironmentObject private var session: SessionStore
    @State private var working = false
    @State private var message: String?
    @State private var currentProfile: LiveProfile?
    var body: some View {
        List {
            Section("Account") {
                NavigationLink { EditProfileView(profile: currentProfile ?? profile) { onChanged(); Task { currentProfile = try? await PlumAPI.profile(profile.id) } } } label: { Label("Edit profile", systemImage: "person.crop.circle") }
                NavigationLink { FollowManagementView() } label: { Label("Followers & following", systemImage: "person.2") }
            }
            Section("Notifications") {
                Button { working = true; Task { defer { working = false }; do { let allowed = try await NotificationRegistration.request(); message = allowed ? "Notifications enabled." : "Notifications are off. Enable them in iOS Settings." } catch { message = error.localizedDescription } } } label: { Label("Enable notifications", systemImage: "bell") }.disabled(working)
                if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
            }
            if isAdmin { NavigationLink("Moderation console") { AdminConsoleView() } }
            Button("Sign out", role: .destructive) { working = true; Task { await session.signOut(); working = false } }.disabled(working)
        }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .onReceive(NotificationCenter.default.publisher(for: .plumPushStatus)) { message = $0.object as? String }
    }
}

struct EditProfileView: View {
    let profile: LiveProfile
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var username: String
    @State private var city: String
    @State private var privateAccount: Bool
    @State private var photo: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var removePhoto = false
    @State private var loadingPhoto = false
    @State private var working = false
    @State private var error: String?
    init(profile: LiveProfile, onSaved: @escaping () -> Void) {
        self.profile = profile; self.onSaved = onSaved
        _displayName = State(initialValue: profile.display_name); _username = State(initialValue: profile.username)
        _city = State(initialValue: profile.city ?? ""); _privateAccount = State(initialValue: profile.visibility == "private")
    }
    var body: some View {
        Form {
            Section("Profile photo") {
                HStack {
                    if let photoData, let image = UIImage(data: photoData) { Image(uiImage: image).resizable().scaledToFill().frame(width: 72, height: 72).clipShape(Circle()) }
                    else { ProfileAvatar(path: removePhoto ? nil : profile.avatar_path, name: displayName, size: 72) }
                    PhotosPicker("Choose photo", selection: $photo, matching: .images).accessibilityIdentifier("profile.photoPicker")
                    if loadingPhoto { ProgressView() }
                }
                if photoData != nil || (!removePhoto && profile.avatar_path != nil) { Button("Remove photo", role: .destructive) { photo = nil; photoData = nil; removePhoto = true; loadingPhoto = false } }
            }
            Section("Profile") {
                TextField("Display name", text: $displayName)
                TextField("Username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("City", text: $city)
                Toggle("Private account", isOn: $privateAccount)
                Text("Private photos, posts, collections, and ratings are visible only to approved followers.").font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.red) }
            Button(working ? "Saving…" : "Save changes") { Task { await save() } }.accessibilityIdentifier("profile.save")
                .disabled(working || loadingPhoto || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || username.range(of: "^[a-z0-9_]{3,30}$", options: .regularExpression) == nil)
        }.navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline).disabled(working)
            .task(id: photo) {
                guard let photo else { return }; loadingPhoto = true; defer { if self.photo == photo { loadingPhoto = false } }
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self), let jpeg = PhotoProcessing.preview(data), jpeg.count <= 5_242_880 else { throw PlumError.invalidPost }
                    guard !Task.isCancelled else { return }; photoData = jpeg; removePhoto = false
                } catch { if !Task.isCancelled { self.error = "Couldn’t load this photo. Choose another image." } }
            }
    }
    private func save() async {
        guard !working else { return }; working = true; error = nil; defer { working = false }
        var uploaded: String?
        do {
            let client = try PlumAPI.client; let me = try await PlumAPI.userID()
            var path = removePhoto ? nil : profile.avatar_path
            if let photoData { let newPath = "\(me.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"; try await client.storage.from("profile-media").upload(newPath, data: photoData, options: .init(contentType: "image/jpeg")); path = newPath; uploaded = newPath }
            let values: [String: AnyJSON] = ["display_name": .string(displayName.trimmingCharacters(in: .whitespacesAndNewlines)), "username": .string(username.lowercased()), "city": .string(city), "visibility": .string(privateAccount ? "private" : "public"), "avatar_path": path.map(AnyJSON.string) ?? .null]
            _ = try await client.from("profiles").update(values).eq("id", value: me).execute()
            if let old = profile.avatar_path, old != path { _ = try? await client.storage.from("profile-media").remove(paths: [old]) }
            onSaved(); dismiss()
        } catch { if let uploaded { _ = try? await PlumServices.client?.storage.from("profile-media").remove(paths: [uploaded]) }; self.error = error.localizedDescription }
    }
}
