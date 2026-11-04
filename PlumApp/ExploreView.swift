import SwiftUI

struct ExploreView: View {
    @State private var store = ExploreStore(service: PlumServices.directory)
    @State private var showingFilters = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 25) {
                    heading
                    searchField
                    filters
                    bodyContent
                }
                .padding(.horizontal, 20).padding(.vertical, 18)
            }
            .background(PlumStyle.cream.ignoresSafeArea())
            .navigationTitle("Explore").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { showingFilters = true } label: { Image(systemName: "line.3.horizontal.decrease.circle") }.accessibilityLabel("Directory filters").accessibilityIdentifier("directory.filters") }
                ToolbarItem(placement: .topBarTrailing) { NavigationLink { AddRestaurantView { _ in Task { await store.loadLanding() } } } label: { Image(systemName: "plus") }.accessibilityLabel("Add restaurant").accessibilityIdentifier("directory.addRestaurant") }
            }
            .sheet(isPresented: $showingFilters) { DirectoryFiltersView(filters: $store.filters) }
            .refreshable { await store.loadLanding(); await store.search() }
            .task { await store.loadLanding() }
            .task(id: searchKey) { await store.search() }
        }
    }

    private var searchKey: String { "\(store.query)|\(store.filters.cuisine ?? "")|\(store.filters.neighborhood ?? "")|\(store.filters.priceLevel ?? 0)" }
    private var heading: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("EXPLORE ATLANTA").font(.caption.weight(.bold)).tracking(1.6).foregroundStyle(.plum.opacity(0.65))
            Text("Find your next\nfavorite table.").font(.system(size: 34, weight: .semibold, design: .serif)).foregroundStyle(.plum)
        }
    }
    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass").foregroundStyle(.plum.opacity(0.7))
            TextField("Search restaurants, dishes, people, lists", text: $store.query).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search).foregroundStyle(.plum)
            if !store.query.isEmpty { Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Clear search") }
        }.padding(.horizontal, 16).frame(height: 53).background(.white.opacity(0.72), in: Capsule()).overlay(Capsule().stroke(.plum.opacity(0.12)))
    }
    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                filterButton("All", store.filters == .init()) { store.filters = .init() }
                if let cuisine = store.filters.cuisine { filterButton(cuisine, true) { store.filters.cuisine = nil } }
                if let neighborhood = store.filters.neighborhood { filterButton(neighborhood, true) { store.filters.neighborhood = nil } }
                if let price = store.filters.priceLevel { filterButton(String(repeating: "$", count: price), true) { store.filters.priceLevel = nil } }
                Button("More filters") { showingFilters = true }.font(.subheadline.weight(.semibold)).foregroundStyle(.plum).padding(.horizontal, 15).padding(.vertical, 9).background(.white.opacity(0.62), in: Capsule())
            }
        }
    }
    private func filterButton(_ title: String, _ active: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(active ? PlumStyle.cream : .plum).padding(.horizontal, 15).padding(.vertical, 9).background(active ? Color.plum : .white.opacity(0.62), in: Capsule()) }.buttonStyle(.plain)
    }
    @ViewBuilder private var bodyContent: some View {
        if store.isLoading { ProgressView("Finding tables…").frame(maxWidth: .infinity).padding(.vertical, 44) }
        else if let error = store.error { errorState(error) }
        else if !store.query.isEmpty || store.filters != .init() { resultSection("BEST MATCHES", store.results) }
        else { resultSection("CURATED FOR A GOOD NIGHT", store.curated); resultSection("ON EVERYONE'S LIST", store.popular); resultSection("DISHES PEOPLE LOVE", store.popularDishes) }
    }
    private func errorState(_ error: String) -> some View {
        ContentUnavailableView("Explore needs a connection", systemImage: "wifi.exclamationmark", description: Text(error)).frame(maxWidth: .infinity).padding(.vertical, 40)
    }
    @ViewBuilder private func destination(_ result: DirectoryResult) -> some View {
        switch result.kind {
        case .restaurant: DirectoryDetailView(restaurantID: result.id)
        case .dish: if let restaurantID = result.restaurantID { DirectoryDetailView(restaurantID: restaurantID, dishID: result.id) }
        case .user: MemberProfileView(id: result.id)
        case .collection: CollectionDetailView(id: result.id)
        }
    }
    private func resultSection(_ title: String, _ results: [DirectoryResult]) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title).font(.caption2.weight(.bold)).tracking(1.35).foregroundStyle(.plum.opacity(0.68))
            if results.isEmpty { ContentUnavailableView("Nothing quite like that", systemImage: "fork.knife", description: Text("Try another restaurant, dish, person, or collection.")) }
            else { ForEach(results) { result in
                NavigationLink { destination(result) } label: { ResultRow(result: result) }.buttonStyle(.plain)
            } }
        }
    }
}

private struct DirectoryFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: DirectoryFilters
    @State private var cuisine = ""
    @State private var neighborhood = ""
    @State private var price = 0
    var body: some View {
        NavigationStack {
            Form {
                Section("Cuisine") { TextField("Any cuisine", text: $cuisine).textInputAutocapitalization(.words).accessibilityIdentifier("directory.filterCuisine") }
                Section("Neighborhood") { TextField("Any Atlanta neighborhood", text: $neighborhood).textInputAutocapitalization(.words).accessibilityIdentifier("directory.filterNeighborhood") }
                Section("Price") { Picker("Price", selection: $price) { Text("Any").tag(0); ForEach(1...4, id: \.self) { Text(String(repeating: "$", count: $0)).tag($0) } }.pickerStyle(.segmented) }
            }
            .navigationTitle("Filter Explore")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Reset") { filters = .init(); cuisine = ""; neighborhood = ""; price = 0 } }
                ToolbarItem(placement: .confirmationAction) { Button("Show results") { filters = .init(cuisine: cuisine.trimmedNil, neighborhood: neighborhood.trimmedNil, priceLevel: price == 0 ? nil : price); dismiss() }.accessibilityIdentifier("directory.applyFilters") }
            }
            .onAppear { cuisine = filters.cuisine ?? ""; neighborhood = filters.neighborhood ?? ""; price = filters.priceLevel ?? 0 }
        }
    }
}

private extension String { var trimmedNil: String? { let value = trimmingCharacters(in: .whitespacesAndNewlines); return value.isEmpty ? nil : value } }

private struct ResultRow: View {
    let result: DirectoryResult
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).font(.title3).foregroundStyle(.plum).frame(width: 58, height: 58).background(Color.plum.opacity(0.1), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 4) { Text(result.title).font(.headline).foregroundStyle(.plum); Text(result.subtitle).font(.subheadline).foregroundStyle(.plum.opacity(0.65)); if result.isExactMatch { Text("Exact match").font(.caption2.weight(.bold)).foregroundStyle(.plum) } }
            Spacer()
        }.padding(10).background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
    }
    private var symbol: String { switch result.kind { case .restaurant: "fork.knife"; case .dish: "star"; case .user: "person"; case .collection: "bookmark" } }
}
