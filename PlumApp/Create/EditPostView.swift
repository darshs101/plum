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
    @State private var dishSuggestions: [DirectoryResult] = []
    @State private var replacementTarget: UUID?
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
        _date = State(initialValue: post.visit_date.flatMap { PostCalendarDate.date(from: $0) } ?? .now)
    }
    var body: some View {
        NavigationStack { Form {
            Section("Restaurant") {
                Text(restaurantID == post.restaurant_id ? post.restaurants?.name ?? "Restaurant" : "New restaurant selected")
                TextField("Search another location", text: $query).accessibilityIdentifier("edit.restaurantSearch")
                ForEach(results.filter { $0.kind == .restaurant }) { result in Button(result.title) { if restaurantID != result.id { ratings = []; added = []; addedNames = [] }; restaurantID = result.id; query = ""; results = [] } }
            }
            Section("Dishes & ratings") {
                ForEach($ratings) { $rating in VStack(alignment: .leading) { Text(rating.dishes?.name ?? "Dish"); Stepper("\(rating.rating.formatted()) stars", value: $rating.rating, in: 0.5...5, step: 0.5).accessibilityIdentifier("edit.rating.\(rating.id.uuidString)"); HStack { Button("Replace") { replacementTarget = rating.id; newDish = ""; dishSuggestions = [] }; Button("Remove dish", role: .destructive) { ratings.removeAll { $0.id == rating.id } } } } }
                ForEach(Array(addedNames.enumerated()), id: \.offset) { index, name in HStack { Text(name); Spacer(); Text(added[index].rating.formatted()); Button("Remove") { added.remove(at: index); addedNames.remove(at: index) } } }
                TextField(replacementTarget == nil ? "Add a dish" : "Replace with a dish", text: $newDish).accessibilityIdentifier("edit.dishName")
                ForEach(dishSuggestions.prefix(5)) { suggestion in Button(suggestion.title) { newDish = suggestion.title; addDish(id: suggestion.id, name: suggestion.title) } }
                Stepper("\(newRating.formatted()) stars", value: $newRating, in: 0.5...5, step: 0.5)
                Button(replacementTarget == nil ? "Add dish" : "Replace dish") { Task { await resolveAndAddDish() } }.disabled(newDish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working)
            }
            Section("Photos") {
                ForEach(photos) { photo in HStack { AsyncImage(url: photo.url) { phase in switch phase { case .success(let image): image.resizable().scaledToFit(); case .failure: Label("Photo unavailable", systemImage: "exclamationmark.triangle").foregroundStyle(.secondary); default: ProgressView().frame(width: 90, height: 90) } }.frame(width: 120, height: 90).plumPhotoEdge(); Spacer(); Button("Remove", role: .destructive) { photos.removeAll { $0.id == photo.id } }.accessibilityIdentifier("edit.removePhoto.\(photo.id.uuidString)") } }
                PhotosPicker(selection: $newPhotos, maxSelectionCount: 8, matching: .images) { Text("Add photos") }
            }
            Section("Details") { TextField("Caption", text: $caption, axis: .vertical).accessibilityIdentifier("edit.caption"); Toggle("Visit date", isOn: $includesDate); if includesDate { DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date) } }
            if let error { Text(error).foregroundStyle(.red) }
            Button("Save changes") { Task { await save() } }.disabled(working || (ratings.isEmpty && added.isEmpty) || (photos.isEmpty && newPhotos.isEmpty)).accessibilityIdentifier("edit.save")
            if working { ProgressView("Saving…") }
        }.disabled(working).navigationTitle("Edit tasting").toolbar { Button("Cancel") { dismiss() }.disabled(working) }
        .task(id: query) { await searchRestaurants() }
        .task(id: newDish) { await searchDishes() }
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
            let entries = ratings.map { SavePostDish(dish_id: $0.dish_id, rating: $0.rating) } + added
            let paths = photos.map(\.storage_path) + uploaded
            // Existing photos may be associated with every remaining dish; new photos
            // initially illustrate all dishes. This preserves the multi-dish invariant
            // without silently dropping a photo when a dish is edited.
            let links = paths.map { SavePostPhotoLink(photo_path: $0, dish_ids: entries.map(\.dish_id)) }
            _ = try await PlumAPI.client.rpc("save_post", params: SavePostParams(post_uuid: post.id, restaurant_uuid: restaurantID, dish_entries: entries, photo_paths: paths, caption_text: caption.isEmpty ? nil : caption, visited_on: includesDate ? PostCalendarDate.string(from: date) : nil, photo_links: links)).execute(); dismiss()
        } catch { if !uploaded.isEmpty { _ = try? await PlumAPI.client.storage.from("post-media").remove(paths: uploaded + uploaded.map { $0 + ".original" }) }; self.error = error.localizedDescription }
    }

    private func searchRestaurants() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { results = []; return }
        do { try await Task.sleep(for: .milliseconds(200)); let found = try await PlumServices.directory.search(query: term, filters: .init()); guard !Task.isCancelled, term == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }; results = found.filter { $0.kind == .restaurant } }
        catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
    private func searchDishes() async {
        let term = newDish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { dishSuggestions = []; return }
        do { try await Task.sleep(for: .milliseconds(180)); let found = try await PlumServices.directory.search(query: term, filters: .init()); guard !Task.isCancelled, term == newDish.trimmingCharacters(in: .whitespacesAndNewlines) else { return }; dishSuggestions = found.filter { $0.kind == .dish && $0.restaurantID == restaurantID } }
        catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
    private func resolveAndAddDish() async {
        let name = newDish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        working = true; defer { working = false }
        do {
            let matches = try await PlumServices.directory.search(query: name, filters: .init()).filter { $0.kind == .dish && $0.restaurantID == restaurantID && $0.title.compare(name, options: .caseInsensitive) == .orderedSame }
            let id: UUID
            if let existing = matches.first { id = existing.id }
            else { id = try await PlumServices.directory.createDish(restaurantID: restaurantID, name: name).id }
            addDish(id: id, name: name)
        } catch { self.error = error.localizedDescription }
    }
    private func addDish(id: UUID, name: String) {
        let existing = ratings.map(\.dish_id) + added.map(\.dish_id)
        guard !existing.contains(id) else { error = "That dish is already in this tasting."; return }
        if let replacementTarget { ratings.removeAll { $0.id == replacementTarget }; self.replacementTarget = nil }
        added.append(.init(dish_id: id, rating: newRating)); addedNames.append(name); newDish = ""; dishSuggestions = []
    }
}
