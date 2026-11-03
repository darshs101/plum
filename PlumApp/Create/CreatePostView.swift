import Foundation
import PhotosUI
import SwiftUI
struct CreatePostView: View {
    @State private var store = ComposerStore(service: PlumServices.directory)
    @State private var restaurantQuery = ""
    @State private var selectedRestaurant: Restaurant?
    @State private var dishes = [DishDraft()]
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var photoCount = 0
    @State private var caption = ""
    @State private var visitDate = Date()
    @State private var includeVisitDate = false
    @State private var didPost = false

    private var matchingRestaurants: [DirectoryResult] {
        guard !restaurantQuery.isEmpty, selectedRestaurant == nil else { return [] }
        return store.restaurantResults
    }

    private var canPost: Bool {
        selectedRestaurant != nil && photoCount > 0 && dishes.allSatisfy {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.rating >= 0.5
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    intro
                    restaurantSection
                    dishesSection
                    photosSection
                    detailsSection
                    postButton
                }
                .padding(20)
                .padding(.bottom, 32)
            }
            .background(PlumStyle.cream.ignoresSafeArea())
            .navigationTitle("Create a post")
            .navigationBarTitleDisplayMode(.large)
            .alert("Your tasting is on Plum", isPresented: $didPost) {
                Button("Done", role: .cancel) { resetComposer() }
            } message: {
                Text("Your post is ready for your friends to discover.")
            }
            .onChange(of: pickerItems) { _, newItems in
                Task { await loadPhotos(newItems) }
            }
            .task(id: restaurantQuery) { await searchRestaurants() }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What did you love?")
                .font(.title2.weight(.bold))
            Text("One restaurant, every dish worth remembering.")
                .foregroundStyle(.secondary)
        }
    }

    private var restaurantSection: some View {
        section("Restaurant", required: true) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(.plum)
                    if let selectedRestaurant {
                        Text(selectedRestaurant.name)
                            .fontWeight(.semibold)
                        Spacer()
                        Button("Change") {
                            self.selectedRestaurant = nil
                            restaurantQuery = ""
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.plum)
                    } else {
                        TextField("Search restaurants", text: $restaurantQuery)
                            .textInputAutocapitalization(.words)
                    }
                }
                .padding(14)

                if !matchingRestaurants.isEmpty {
                    Divider()
                    ForEach(matchingRestaurants) { restaurant in
                        Button {
                            selectedRestaurant = Restaurant(id: restaurant.id, name: restaurant.title, neighborhood: restaurant.subtitle, address: restaurant.subtitle, cuisine: "", priceLevel: restaurant.priceLevel ?? 0)
                            restaurantQuery = restaurant.title
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(restaurant.title).fontWeight(.medium)
                                    Text(restaurant.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: PlumStyle.cornerRadius))
        }
    }

    private var dishesSection: some View {
        section("Dishes", required: true) {
            VStack(spacing: 14) {
                ForEach($dishes) { $dish in
                    DishEditor(dish: $dish, suggestions: store.dishSuggestions[dish.id] ?? [], canRemove: dishes.count > 1, onSearch: {
                        Task { await store.findDishes(for: dish.id, text: dish.name) }
                    }) {
                        dishes.removeAll { $0.id == dish.id }
                    }
                }
                Button {
                    dishes.append(DishDraft())
                } label: {
                    Label("Add another dish", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .foregroundStyle(.plum)
                .background(Color.plum.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var photosSection: some View {
        section("Photos", required: true) {
            VStack(alignment: .leading, spacing: 12) {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 8, matching: .images) {
                    HStack(spacing: 14) {
                        Image(systemName: photoCount == 0 ? "camera.fill" : "photo.stack.fill")
                            .font(.title3)
                            .frame(width: 42, height: 42)
                            .background(Color.plum.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(photoCount == 0 ? "Add your photos" : "\(photoCount) photo\(photoCount == 1 ? "" : "s") selected")
                                .fontWeight(.semibold)
                            Text("A photo can feature more than one dish")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                    }
                    .padding(14)
                    .background(.background, in: RoundedRectangle(cornerRadius: PlumStyle.cornerRadius))
                }
                .buttonStyle(.plain)
                if photoCount == 0 {
                    Label("At least one photo is needed to post.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var detailsSection: some View {
        section("A little more", required: false) {
            VStack(spacing: 0) {
                TextField("Caption (optional)", text: $caption, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(14)
                Divider()
                Toggle("Add visit date", isOn: $includeVisitDate)
                    .tint(.plum)
                    .padding(14)
                if includeVisitDate {
                    Divider()
                    DatePicker("When did you go?", selection: $visitDate, in: ...Date(), displayedComponents: .date)
                        .padding(14)
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: PlumStyle.cornerRadius))
        }
    }

    private var postButton: some View {
        Button { Task { await publish() } } label: {
            Group { if store.isWorking { ProgressView().tint(.white) } else { Text("Post tasting") } }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(canPost ? Color.plum : Color.gray.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
        .disabled(!canPost || store.isWorking)
        .accessibilityHint(canPost ? "Publishes your tasting" : "Choose a restaurant, add a dish, and attach a photo to post")
    }

    private func section<Content: View>(_ title: String, required: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 4) {
                Text(title).font(.headline)
                if required { Text("*").foregroundStyle(.plum).fontWeight(.bold) }
            }
            content()
        }
    }

    private func resetComposer() {
        restaurantQuery = ""
        selectedRestaurant = nil
        dishes = [DishDraft()]
        pickerItems = []
        photoCount = 0
        caption = ""
        includeVisitDate = false
        visitDate = Date()
    }

    private func searchRestaurants() async {
        store.restaurantQuery = restaurantQuery
        await store.findRestaurants()
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var uploads: [PhotoUploadDraft] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                uploads.append(.init(id: UUID(), data: data, contentType: "image/jpeg", linkedDishIDs: []))
            }
        }
        store.photos = uploads
        photoCount = uploads.count
    }

    private func publish() async {
        store.selectedRestaurant = selectedRestaurant
        store.dishes = dishes.map { .init(id: $0.id, dishID: nil, proposedName: $0.name, rating: $0.rating) }
        store.caption = caption
        store.includesVisitDate = includeVisitDate
        store.visitDate = visitDate
        await store.publish()
        if store.success { didPost = true }
    }
}

private struct DishEditor: View {
    @Binding var dish: DishDraft
    let suggestions: [DirectoryResult]
    let canRemove: Bool
    let onSearch: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Dish").font(.subheadline.weight(.semibold))
                Spacer()
                if canRemove {
                    Button(role: .destructive, action: remove) {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Remove \(dish.name.isEmpty ? "dish" : dish.name)")
                }
            }
            TextField("Search or name a dish", text: $dish.name)
                .textInputAutocapitalization(.words)
                .onChange(of: dish.name) { _, _ in onSearch() }
                .padding(12)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            if !suggestions.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(suggestions.prefix(4)) { result in
                        Button(result.title) { dish.name = result.title }
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.plum.opacity(0.09), in: Capsule())
                            .foregroundStyle(.plum)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Your rating").font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f", dish.rating))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.plum)
                }
                StarRating(rating: $dish.rating)
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: PlumStyle.cornerRadius))
    }
}

private struct StarRating: View {
    @Binding var rating: Double
    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { star in
                Button { rating = rating == Double(star) ? Double(star) - 0.5 : Double(star) } label: {
                    Image(systemName: symbol(for: Double(star)))
                        .font(.title3)
                        .foregroundStyle(.plum)
                        .frame(minWidth: 34, minHeight: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(star) stars")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func symbol(for star: Double) -> String {
        if rating >= star { return "star.fill" }
        if rating == star - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += lineHeight + spacing; lineHeight = 0 }
            x += size.width + spacing; lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: y + lineHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += lineHeight + spacing; lineHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct DishDraft: Identifiable {
    let id = UUID()
    var name = ""
    var rating = 4.5
}
