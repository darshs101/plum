import SwiftUI

struct DirectoryDetailView: View {
    let restaurantID: UUID
    var dishID: UUID? = nil
    @State private var restaurant: Restaurant?
    @State private var dishes: [LiveDish] = []
    @State private var posts: [LivePost] = []
    @State private var average: Double?
    @State private var ratings = 0
    @State private var error: String?
    @State private var saved = false
    @State private var working = false
    @State private var collectionsOpen = false
    @State private var reportOpen = false
    @State private var resolvedDishID: UUID?
    private var resolvedID: UUID { restaurant?.id ?? restaurantID }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let error { Text(error).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
                if let restaurant {
                    AsyncImage(url: restaurant.photoURL) { $0.resizable().scaledToFill() } placeholder: { Color.plum.opacity(0.1) }.frame(height: 240).clipped().clipShape(RoundedRectangle(cornerRadius: 16))
                    Text(dishID.flatMap { id in dishes.first { $0.id == (resolvedDishID ?? id) }?.name } ?? restaurant.name).font(.largeTitle.bold())
                    Text(restaurant.address).foregroundStyle(.secondary)
                    if !restaurant.cuisine.isEmpty { Text("\(restaurant.cuisine) · \(restaurant.neighborhood) · \(String(repeating: "$", count: restaurant.priceLevel))").font(.subheadline) }
                    if let average { Label("\(average.formatted(.number.precision(.fractionLength(1)))) · \(ratings) public ratings", systemImage: "star.fill").foregroundStyle(.plum) }
                    else { Text("No public ratings yet.").foregroundStyle(.secondary) }
                    HStack {
                        Button(saved ? "Remove from Saved Places" : "Save place") { working = true; Task { defer { working = false }; do { try await PlumServices.directory.toggleSavedPlace(restaurantID: resolvedID, isSaved: !saved); saved.toggle() } catch { self.error = error.localizedDescription } } }.buttonStyle(.bordered).disabled(working)
                        Button { collectionsOpen = true } label: { Image(systemName: "text.badge.plus") }.accessibilityLabel("Add to collection")
                        Button { reportOpen = true } label: { Image(systemName: "flag") }.accessibilityLabel("Report duplicate or listing")
                    }
                    if dishID == nil {
                        Text("Dishes").font(.title2.bold())
                        ForEach(dishes) { dish in NavigationLink(dish.name) { DirectoryDetailView(restaurantID: resolvedID, dishID: dish.id) } }
                        if dishes.isEmpty { Text("Add the first dish by creating a tasting.").foregroundStyle(.secondary) }
                    }
                    Text("Public activity").font(.title2.bold())
                    ForEach(posts) { LivePostCard(post: $0) }
                    if posts.isEmpty { Text("No public tastings yet.").foregroundStyle(.secondary) }
                } else if error == nil { ProgressView("Loading…") }
            }.padding(20)
        }.navigationTitle(dishID == nil ? "Restaurant" : "Dish").navigationBarTitleDisplayMode(.inline)
            .task { await load() }.refreshable { await load() }
            .sheet(isPresented: $collectionsOpen) { AddToCollectionView(restaurantID: resolvedID) }
            .sheet(isPresented: $reportOpen) { ReportContentView(type: dishID == nil ? "restaurant" : "dish", id: dishID ?? restaurantID) }
    }
    private func load() async {
        error = nil
        do {
            restaurant = try await PlumServices.directory.restaurant(id: restaurantID)
            resolvedDishID = dishID
            if let dishID {
                struct Merge: Decodable { let target_id: UUID }
                var current = dishID
                for _ in 0..<10 { let merges: [Merge] = try await PlumAPI.client.from("record_merge_history").select("target_id").eq("source_id", value: current).eq("record_type", value: "dish").execute().value; guard let next = merges.first?.target_id else { break }; current = next }
                resolvedDishID = current
            }
            dishes = try await PlumAPI.client.from("dishes").select("id,name,restaurant_id").eq("restaurant_id", value: resolvedID).order("name").execute().value
            posts = try await PlumAPI.publicPosts(restaurant: resolvedID, dish: resolvedDishID)
            struct Aggregate: Decodable { let average_rating: Double?; let rating_count: Int }
            let aggregates: [Aggregate]
            if let dishID = resolvedDishID { aggregates = try await PlumAPI.client.from("public_dish_aggregates").select("average_rating,rating_count").eq("dish_id", value: dishID).execute().value }
            else { aggregates = try await PlumAPI.client.from("public_restaurant_aggregates").select("average_rating,rating_count").eq("restaurant_id", value: resolvedID).execute().value }
            average = aggregates.first?.average_rating; ratings = aggregates.first?.rating_count ?? 0
            let savedLists = try await PlumAPI.collections().filter { $0.kind == "saved_places" }
            if let list = savedLists.first { let items: [LiveCollectionItem] = try await PlumAPI.client.from("collection_items").select("*,restaurants(name)").eq("collection_id", value: list.id).eq("restaurant_id", value: resolvedID).execute().value; saved = !items.isEmpty }
        } catch { self.error = error.localizedDescription }
    }
}
