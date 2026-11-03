import SwiftUI

struct NewCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""; @State private var ranked = false; @State private var isPublic = false; @State private var error: String?; @State private var working = false
    var body: some View {
        NavigationStack { Form {
            TextField("Collection title", text: $title); Toggle("Ranked list", isOn: $ranked); Toggle("Public", isOn: $isPublic)
            if let error { Text(error).foregroundStyle(.red) }
            Button("Create collection") { working = true; Task { defer { working = false }; do {
                let me = try await PlumAPI.userID()
                struct New: Encodable { let owner_id: UUID; let title: String; let kind: String; let is_public: Bool }
                _ = try await PlumAPI.client.from("collections").insert(New(owner_id: me, title: title, kind: ranked ? "ranked" : "standard", is_public: isPublic)).execute(); dismiss()
            } catch { self.error = error.localizedDescription } } }.disabled(working || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }.navigationTitle("New collection").toolbar { Button("Cancel") { dismiss() } } }
    }
}
struct AddToCollectionView: View {
    var restaurantID: UUID? = nil
    var postID: UUID? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var collections: [LiveCollection] = []; @State private var error: String?; @State private var working = false
    var body: some View {
        NavigationStack { List {
            if let error { Text(error).foregroundStyle(.red) }
            if collections.isEmpty { Text("Create a collection from your profile to save this item.") }
            ForEach(collections) { collection in Button(collection.title) { working = true; Task { defer { working = false }; do {
                struct New: Encodable { let collection_id: UUID; let restaurant_id: UUID?; let post_id: UUID?; let rank: Int? }
                let items: [LiveCollectionItem] = try await PlumAPI.client.from("collection_items").select("*,restaurants(name)").eq("collection_id", value: collection.id).execute().value
                _ = try await PlumAPI.client.from("collection_items").insert(New(collection_id: collection.id, restaurant_id: restaurantID, post_id: postID, rank: collection.kind == "ranked" ? (items.compactMap(\.rank).max() ?? 0) + 1 : nil)).execute(); dismiss()
            } catch { self.error = error.localizedDescription } } }.disabled(working) }
        }.navigationTitle("Save to collection").toolbar { Button("Done") { dismiss() } }.task { do { collections = try await PlumAPI.collections() } catch { self.error = error.localizedDescription } } }
    }
}
struct CollectionDetailView: View {
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var settingsOpen = false
    @State private var collection: LiveCollection?
    @State private var items: [LiveCollectionItem] = []
    @State private var owner = false
    @State private var error: String?
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
            if let collection {
                Section { Label(collection.kind == "ranked" ? "Manual ranking" : "Unranked collection", systemImage: collection.kind == "ranked" ? "list.number" : "bookmark"); Text(collection.is_public ? "Public" : "Private") }
                if items.isEmpty { Text("This collection is empty. Save restaurants from Explore or posts from their tasting page.") }
                ForEach(items) { item in
                    HStack {
                        if collection.kind == "ranked" { Text("\(item.rank ?? 0).").foregroundStyle(.secondary) }
                        if let restaurant = item.restaurant_id { NavigationLink(item.restaurants?.name ?? "Restaurant") { DirectoryDetailView(restaurantID: restaurant) } }
                        else if let post = item.post_id { NavigationLink("Open saved tasting") { PostDetailView(id: post) } }
                        else { Text("Unavailable saved item").foregroundStyle(.secondary) }
                    }.deleteDisabled(!owner).moveDisabled(!owner || collection.kind != "ranked")
                }.onDelete { offsets in guard owner else { return }; let removed = offsets.map { items[$0] }; Task { do { for item in removed { _ = try await PlumAPI.client.from("collection_items").delete().eq("id", value: item.id).execute() }; await load() } catch { self.error = error.localizedDescription } } }
                .onMove { offsets, destination in guard owner else { return }; items.move(fromOffsets: offsets, toOffset: destination); Task { do { struct Reorder: Encodable { let collection_uuid: UUID; let ordered_items: [UUID] }; _ = try await PlumAPI.client.rpc("reorder_collection", params: Reorder(collection_uuid: id, ordered_items: items.map(\.id))).execute(); await load() } catch { self.error = error.localizedDescription; await load() } } }
            }
        }.navigationTitle(collection?.title ?? "Collection").toolbar { if owner { EditButton(); Button { settingsOpen = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Collection settings") } }
        .sheet(isPresented: $settingsOpen) { if let collection { EditCollectionView(collection: collection) { deleted in if deleted { dismiss() } else { Task { await load() } } } } }
        .task { await load() }.refreshable { await load() }
    }
    private func load() async { do { collection = try await PlumAPI.client.from("collections").select().eq("id", value: id).single().execute().value; owner = try await collection?.owner_id == PlumAPI.userID(); items = try await PlumAPI.client.from("collection_items").select("*,restaurants(name)").eq("collection_id", value: id).order("rank").order("created_at").execute().value } catch { self.error = error.localizedDescription } }
}

struct EditCollectionView: View {
    let collection: LiveCollection
    var onChanged: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var ranked: Bool
    @State private var isPublic: Bool
    @State private var error: String?
    @State private var working = false
    @State private var deleting = false
    init(collection: LiveCollection, onChanged: @escaping (Bool) -> Void) {
        self.collection = collection; self.onChanged = onChanged
        _title = State(initialValue: collection.title); _ranked = State(initialValue: collection.kind == "ranked"); _isPublic = State(initialValue: collection.is_public)
    }
    var body: some View {
        NavigationStack { Form {
            TextField("Title", text: $title)
            Toggle("Public", isOn: $isPublic)
            if collection.kind != "saved_places" { Toggle("Ranked list", isOn: $ranked) }
            if let error { Text(error).foregroundStyle(.red) }
            Button("Save changes") { working = true; Task { defer { working = false }; do {
                struct Update: Encodable { let title: String; let kind: String; let is_public: Bool }
                _ = try await PlumAPI.client.from("collections").update(Update(title: title, kind: collection.kind == "saved_places" ? "saved_places" : ranked ? "ranked" : "standard", is_public: isPublic)).eq("id", value: collection.id).execute()
                onChanged(false); dismiss()
            } catch { self.error = error.localizedDescription } } }.disabled(working || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if collection.kind != "saved_places" { Button("Delete collection", role: .destructive) { deleting = true }.disabled(working) }
        }.navigationTitle("Collection settings").toolbar { Button("Cancel") { dismiss() }.disabled(working) }
        .confirmationDialog("Delete this collection? Saved restaurants and posts remain on Plum.", isPresented: $deleting) { Button("Delete collection", role: .destructive) { working = true; Task { defer { working = false }; do { _ = try await PlumAPI.client.from("collections").delete().eq("id", value: collection.id).execute(); onChanged(true); dismiss() } catch { self.error = error.localizedDescription } } } }
        }
    }
}
