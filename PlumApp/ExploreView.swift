import SwiftUI

struct ExploreView: View {
    @State private var store = ExploreStore(service: PlumServices.directory)

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
            TextField("Search restaurants, dishes, people, lists", text: $store.query).textInputAutocapitalization(.words).foregroundStyle(.plum)
            if !store.query.isEmpty { Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Clear search") }
        }.padding(.horizontal, 16).frame(height: 53).background(.white.opacity(0.72), in: Capsule()).overlay(Capsule().stroke(.plum.opacity(0.12)))
    }
    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                filterButton("All", store.filters == .init()) { store.filters = .init() }
                filterButton("Italian", store.filters.cuisine == "Italian") { store.filters.cuisine = store.filters.cuisine == "Italian" ? nil : "Italian" }
                filterButton("Old Fourth Ward", store.filters.neighborhood == "Old Fourth Ward") { store.filters.neighborhood = store.filters.neighborhood == "Old Fourth Ward" ? nil : "Old Fourth Ward" }
                filterButton("$–$$", store.filters.priceLevel == 2) { store.filters.priceLevel = store.filters.priceLevel == 2 ? nil : 2 }
                filterButton("$$$+", store.filters.priceLevel == 3) { store.filters.priceLevel = store.filters.priceLevel == 3 ? nil : 3 }
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
        else { resultSection("CURATED FOR A GOOD NIGHT", store.curated); resultSection("ON EVERYONE'S LIST", store.popular) }
    }
    private func errorState(_ error: String) -> some View {
        ContentUnavailableView("Explore needs a connection", systemImage: "wifi.exclamationmark", description: Text(error)).frame(maxWidth: .infinity).padding(.vertical, 40)
    }
    private func resultSection(_ title: String, _ results: [DirectoryResult]) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title).font(.caption2.weight(.bold)).tracking(1.35).foregroundStyle(.plum.opacity(0.68))
            if results.isEmpty { ContentUnavailableView("Nothing quite like that", systemImage: "fork.knife", description: Text("Try another restaurant, dish, person, or collection.")) }
            else { ForEach(results) { ResultRow(result: $0) } }
        }
    }
}

private struct ResultRow: View {
    let result: DirectoryResult
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).font(.title3).foregroundStyle(.plum).frame(width: 58, height: 58).background(Color.plum.opacity(0.1), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 4) { Text(result.title).font(.headline).foregroundStyle(.plum); Text(result.subtitle).font(.subheadline).foregroundStyle(.plum.opacity(0.65)); if result.isExactMatch { Text("Exact match").font(.caption2.weight(.bold)).foregroundStyle(.plum) } }
            Spacer()
        }.padding(10).background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
    private var symbol: String { switch result.kind { case .restaurant: "fork.knife"; case .dish: "star"; case .user: "person"; case .collection: "bookmark" } }
}
