import SwiftUI

struct ExploreView: View {
    @State private var searchText = ""
    @State private var selectedFilter: ExploreFilter?

    private var visiblePlaces: [ExplorePlace] {
        let filtered = ExplorePlace.samples.filter { place in
            (selectedFilter == nil || selectedFilter!.matches(place)) &&
            (searchText.isEmpty || place.searchTerms.localizedCaseInsensitiveContains(searchText))
        }
        guard !searchText.isEmpty else { return filtered }
        return filtered.sorted { lhs, rhs in
            let leftExact = lhs.name.localizedCaseInsensitiveCompare(searchText) == .orderedSame
            let rightExact = rhs.name.localizedCaseInsensitiveCompare(searchText) == .orderedSame
            if leftExact != rightExact { return leftExact }
            return lhs.name < rhs.name
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 25) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("EXPLORE ATLANTA")
                            .font(.caption.weight(.bold))
                            .tracking(1.6)
                            .foregroundStyle(.plum.opacity(0.65))
                        Text("Find your next\nfavorite table.")
                            .font(.system(size: 34, weight: .semibold, design: .serif))
                            .foregroundStyle(.plum)
                    }

                    searchField
                    filterRow

                    if !searchText.isEmpty || selectedFilter != nil {
                        searchResults
                    } else {
                        collectionSection
                        nearbySection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .background(PlumStyle.cream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.plum.opacity(0.7))
            TextField("Search restaurants, dishes, neighborhoods", text: $searchText)
                .textInputAutocapitalization(.words)
                .foregroundStyle(.plum)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.plum.opacity(0.35))
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 53)
        .background(.white.opacity(0.72), in: Capsule())
        .overlay(Capsule().stroke(.plum.opacity(0.12), lineWidth: 1))
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                filterButton(nil, title: "All")
                ForEach(ExploreFilter.allCases) { filter in
                    filterButton(filter, title: filter.title)
                }
            }
        }
        .padding(.horizontal, -20)
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }

    private func filterButton(_ filter: ExploreFilter?, title: String) -> some View {
        let active = selectedFilter == filter
        return Button { selectedFilter = active ? nil : filter } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(active ? PlumStyle.cream : .plum)
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background(active ? Color.plum : .white.opacity(0.62), in: Capsule())
                .overlay(Capsule().stroke(.plum.opacity(active ? 0 : 0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeading("CURATED FOR A GOOD NIGHT")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 13) {
                    ForEach(ExploreCollection.samples) { collection in
                        CollectionCard(collection: collection)
                    }
                }
            }
            .padding(.horizontal, -20)
            .contentMargins(.horizontal, 20, for: .scrollContent)
        }
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                sectionHeading("ON EVERYONE'S LIST")
                Spacer()
                Text("Atlanta")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.plum.opacity(0.55))
            }
            ForEach(ExplorePlace.samples.prefix(3)) { place in
                PlaceRow(place: place)
            }
        }
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                sectionHeading(searchText.isEmpty ? "MATCHES" : "BEST MATCHES")
                Spacer()
                Text("\(visiblePlaces.count) places")
                    .font(.caption)
                    .foregroundStyle(.plum.opacity(0.55))
            }
            if visiblePlaces.isEmpty {
                ContentUnavailableView("Nothing quite like that", systemImage: "fork.knife", description: Text("Try a cuisine, dish, or Atlanta neighborhood."))
                    .foregroundStyle(.plum)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                ForEach(visiblePlaces) { place in PlaceRow(place: place) }
            }
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .tracking(1.35)
            .foregroundStyle(.plum.opacity(0.68))
    }
}

private struct CollectionCard: View {
    let collection: ExploreCollection
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(collection.colors)
                    .frame(width: 221, height: 143)
                Image(systemName: collection.symbol)
                    .font(.system(size: 47, weight: .light))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                Text(collection.count)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(.black.opacity(0.24), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(11)
            }
            Text(collection.title)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(.plum)
            Text(collection.subtitle)
                .font(.caption)
                .foregroundStyle(.plum.opacity(0.6))
        }
        .frame(width: 221, alignment: .leading)
    }
}

private struct PlaceRow: View {
    let place: ExplorePlace
    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(place.colors)
                .frame(width: 72, height: 72)
                .overlay(Image(systemName: place.symbol).foregroundStyle(.white.opacity(0.85)).font(.title2))
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(place.name).font(.headline).foregroundStyle(.plum)
                    Spacer()
                    Text(place.price).font(.subheadline.weight(.bold)).foregroundStyle(.plum.opacity(0.66))
                }
                Text("\(place.cuisine) · \(place.neighborhood)")
                    .font(.subheadline).foregroundStyle(.plum.opacity(0.65))
                Label(place.note, systemImage: "sparkle")
                    .font(.caption).foregroundStyle(.plum.opacity(0.75))
            }
        }
        .padding(10)
        .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

private enum ExploreFilter: String, CaseIterable, Identifiable {
    case italian, korean, oldFourthWard, buckhead, affordable, occasion
    var id: String { rawValue }
    var title: String { switch self { case .italian: "Italian"; case .korean: "Korean"; case .oldFourthWard: "Old Fourth Ward"; case .buckhead: "Buckhead"; case .affordable: "$–$$"; case .occasion: "$$$+" } }
    func matches(_ place: ExplorePlace) -> Bool {
        switch self { case .italian: place.cuisine == "Italian"; case .korean: place.cuisine == "Korean"; case .oldFourthWard: place.neighborhood == "Old Fourth Ward"; case .buckhead: place.neighborhood == "Buckhead"; case .affordable: place.price.count < 3; case .occasion: place.price.count >= 3 }
    }
}

private struct ExplorePlace: Identifiable {
    let id = UUID(); let name, cuisine, neighborhood, price, note, symbol: String; let colors: LinearGradient
    var searchTerms: String { "\(name) \(cuisine) \(neighborhood) \(note)" }
    static let samples = [
        ExplorePlace(name: "BoccaLupo", cuisine: "Italian", neighborhood: "Inman Park", price: "$$$", note: "The black spaghetti order", symbol: "fork.knife", colors: .init(colors: [.orange, .brown], startPoint: .topLeading, endPoint: .bottomTrailing)),
        ExplorePlace(name: "Gaja Korean", cuisine: "Korean", neighborhood: "East Atlanta", price: "$$", note: "Late-night favorite", symbol: "flame.fill", colors: .init(colors: [.red.opacity(0.8), .plum], startPoint: .topLeading, endPoint: .bottomTrailing)),
        ExplorePlace(name: "Delbar", cuisine: "Persian", neighborhood: "Inman Park", price: "$$", note: "Save room for tahdig", symbol: "leaf.fill", colors: .init(colors: [.mint, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)),
        ExplorePlace(name: "Miller Union", cuisine: "New American", neighborhood: "Westside", price: "$$$", note: "A long-lunch classic", symbol: "wineglass.fill", colors: .init(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)),
        ExplorePlace(name: "The Chastain", cuisine: "French", neighborhood: "Buckhead", price: "$$$$", note: "For an occasion", symbol: "sparkles", colors: .init(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)),
        ExplorePlace(name: "Staplehouse", cuisine: "New American", neighborhood: "Old Fourth Ward", price: "$$$", note: "Seasonal and special", symbol: "carrot.fill", colors: .init(colors: [.green, .brown], startPoint: .topLeading, endPoint: .bottomTrailing))
    ]
}

private struct ExploreCollection: Identifiable {
    let id = UUID(); let title, subtitle, count, symbol: String; let colors: LinearGradient
    static let samples = [
        ExploreCollection(title: "First Date, No Fumbles", subtitle: "Dim lights, good playlists", count: "12 places", symbol: "heart.fill", colors: .init(colors: [.plum, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)),
        ExploreCollection(title: "Atlanta After Dark", subtitle: "Tables worth staying out for", count: "18 places", symbol: "moon.stars.fill", colors: .init(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)),
        ExploreCollection(title: "Sunday, Slowly", subtitle: "Brunch with a little ceremony", count: "9 places", symbol: "cup.and.saucer.fill", colors: .init(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
    ]
}
