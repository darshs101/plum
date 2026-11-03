import SwiftUI
import PhotosUI

struct EditPostView: View {
    let post: LivePost
    @Environment(\.dismiss) private var dismiss
    @State private var caption: String
    @State private var ratings: [LiveRating]
    @State private var photos: [LivePhoto]
    @State private var newPhotos: [PhotosPickerItem] = []
    @State private var restaurantID: UUID
    @State private var query = ""
    @State private var results: [DirectoryResult] = []
    @State private var newDish = ""
    @State private var newRating = 4.0
    @State private var added: [SavePostDish] = []
    @State private var addedNames: [String] = []
    @State private var working = false
    @State private var error: String?
    @State private var date: Date
    @State private var includesDate: Bool
    init(post: LivePost) {
        self.post = post
        _caption = State(initialValue: post.caption ?? ""); _ratings = State(initialValue: post.post_dishes); _photos = State(initialValue: post.post_photos); _restaurantID = State(initialValue: post.restaurant_id)
        _includesDate = State(initialValue: post.visit_date != nil)
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        _date = State(initialValue: post.visit_date.flatMap(formatter.date(from:)) ?? .now)
    }
    var body: some View {
        NavigationStack { Form {
            Section("Restaurant") {
                Text(restaurantID == post.restaurant_id ? post.restaurants?.name ?? "Restaurant" : "New restaurant selected")
                TextField("Search another location", text: $query)
                ForEach(results.filter { $0.kind == .restaurant }) { result in Button(result.title) { if restaurantID != result.id { ratings = []; added = []; addedNames = [] }; restaurantID = result.id; query = ""; results = [] } }
            }
            Section("Dishes & ratings") {
                ForEach($ratings) { $rating in VStack(alignment: .leading) { Text(rating.dishes?.name ?? "Dish"); Stepper("\(rating.rating.formatted()) stars", value: $rating.rating, in: 0.5...5, step: 0.5); Button("Remove dish", role: .destructive) { ratings.removeAll { $0.id == rating.id } } } }
                ForEach(Array(addedNames.enumerated()), id: \.offset) { index, name in HStack { Text(name); Spacer(); Text(added[index].rating.formatted()); Button("Remove") { added.remove(at: index); addedNames.remove(at: index) } } }
                TextField("Add a dish", text: $newDish)
                Stepper("\(newRating.formatted()) stars", value: $newRating, in: 0.5...5, step: 0.5)
                Button("Add dish") { working = true; Task { defer { working = false }; do { let matches = try await PlumServices.directory.search(query: newDish, filters: .init()).filter { $0.kind == .dish && $0.restaurantID == restaurantID && $0.title.lowercased() == newDish.lowercased() }; let id: UUID; if let existing = matches.first { id = existing.id } else { id = try await PlumServices.directory.createDish(restaurantID: restaurantID, name: newDish).id }; added.append(.init(dish_id: id, rating: newRating)); addedNames.append(newDish); newDish = "" } catch { self.error = error.localizedDescription } } }.disabled(newDish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working)
            }
            Section("Photos") {
                ForEach(photos) { photo in HStack { AsyncImage(url: photo.url) { $0.resizable().scaledToFit() } placeholder: { ProgressView() }.frame(height: 90); Spacer(); Button("Remove", role: .destructive) { photos.removeAll { $0.id == photo.id } } } }
                PhotosPicker(selection: $newPhotos, maxSelectionCount: 8, matching: .images) { Text("Add photos") }
            }
            Section("Details") { TextField("Caption", text: $caption, axis: .vertical); Toggle("Visit date", isOn: $includesDate); if includesDate { DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date) } }
            if let error { Text(error).foregroundStyle(.red) }
            Button("Save changes") { Task { await save() } }.disabled(working || (ratings.isEmpty && added.isEmpty) || (photos.isEmpty && newPhotos.isEmpty))
            if working { ProgressView("Saving…") }
        }.navigationTitle("Edit tasting").toolbar { Button("Cancel") { dismiss() }.disabled(working) }
        .task(id: query) { guard !query.isEmpty else { return }; do { results = try await PlumServices.directory.search(query: query, filters: .init()) } catch { self.error = error.localizedDescription } }
        }
    }
    private func save() async {
        working = true; defer { working = false }; var uploaded: [String] = []
        do {
            let me = try await PlumAPI.userID()
            for item in newPhotos {
                guard let data = try await item.loadTransferable(type: Data.self), let jpeg = PhotoProcessing.preview(data) else { throw PlumError.invalidPost }
                let path = "\(me.uuidString.lowercased())/\(post.id.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
                try await PlumAPI.client.storage.from("post-media").upload(path, data: jpeg, options: .init(contentType: "image/jpeg")); uploaded.append(path)
                try await PlumAPI.client.storage.from("post-media").upload(path + ".original", data: data, options: .init(contentType: item.supportedContentTypes.first?.preferredMIMEType ?? "application/octet-stream"))
            }
            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
            _ = try await PlumAPI.client.rpc("save_post", params: SavePostParams(post_uuid: post.id, restaurant_uuid: restaurantID, dish_entries: ratings.map { .init(dish_id: $0.dish_id, rating: $0.rating) } + added, photo_paths: photos.map(\.storage_path) + uploaded, caption_text: caption.isEmpty ? nil : caption, visited_on: includesDate ? formatter.string(from: date) : nil)).execute(); dismiss()
        } catch { if !uploaded.isEmpty { _ = try? await PlumAPI.client.storage.from("post-media").remove(paths: uploaded + uploaded.map { $0 + ".original" }) }; self.error = error.localizedDescription }
    }
}
