import Foundation
import Observation

enum DirectorySearchKind: String, CaseIterable, Identifiable, Sendable { case restaurant, dish, user, collection; var id: String { rawValue } }
struct DirectoryFilters: Equatable, Sendable { var cuisine: String?; var neighborhood: String?; var priceLevel: Int? }
struct DirectoryResult: Identifiable, Hashable, Sendable { let id: UUID; let kind: DirectorySearchKind; let title: String; let subtitle: String; let priceLevel: Int?; let restaurantID: UUID?; let isExactMatch: Bool }
struct PostDishDraftRequest: Identifiable, Sendable { let id: UUID; var dishID: UUID?; var proposedName: String; var rating: Double }
struct PhotoUploadDraft: Identifiable, Sendable { let id: UUID; let data: Data; let contentType: String; var linkedDishIDs: Set<UUID>; var originalData: Data? = nil; var originalContentType: String? = nil }
struct PostDraftRequest: Sendable { let restaurantID: UUID; let dishes: [PostDishDraftRequest]; let photos: [PhotoUploadDraft]; let caption: String?; let visitDate: Date? }
struct RestaurantDraft: Sendable { let name: String; let address: String; let neighborhood: String?; let cuisine: String?; let priceLevel: Int?; let photo: PhotoUploadDraft }

protocol DirectoryServing: Sendable {
    func search(query: String, filters: DirectoryFilters) async throws -> [DirectoryResult]
    func curatedCollections() async throws -> [DirectoryResult]
    func popularNearby() async throws -> [DirectoryResult]
    func popularDishes() async throws -> [DirectoryResult]
    func restaurant(id: UUID) async throws -> Restaurant
    func createRestaurant(_ draft: RestaurantDraft) async throws -> Restaurant
    func createDish(restaurantID: UUID, name: String) async throws -> Dish
    func createPost(_ draft: PostDraftRequest) async throws
    func toggleSavedPlace(restaurantID: UUID, isSaved: Bool) async throws
}
struct UnconfiguredDirectoryService: DirectoryServing {
    func search(query: String, filters: DirectoryFilters) async throws -> [DirectoryResult] { throw PlumError.unavailable }
    func curatedCollections() async throws -> [DirectoryResult] { throw PlumError.unavailable }
    func popularNearby() async throws -> [DirectoryResult] { throw PlumError.unavailable }
    func popularDishes() async throws -> [DirectoryResult] { throw PlumError.unavailable }
    func restaurant(id: UUID) async throws -> Restaurant { throw PlumError.unavailable }
    func createRestaurant(_ draft: RestaurantDraft) async throws -> Restaurant { throw PlumError.unavailable }
    func createDish(restaurantID: UUID, name: String) async throws -> Dish { throw PlumError.unavailable }
    func createPost(_ draft: PostDraftRequest) async throws { throw PlumError.unavailable }
    func toggleSavedPlace(restaurantID: UUID, isSaved: Bool) async throws { throw PlumError.unavailable }
}

@MainActor @Observable final class ExploreStore {
    private let service: any DirectoryServing
    var query = ""; var filters = DirectoryFilters(); var results: [DirectoryResult] = []; var curated: [DirectoryResult] = []; var popular: [DirectoryResult] = []; var popularDishes: [DirectoryResult] = []; var isLoading = false; var error: String?
    init(service: any DirectoryServing = UnconfiguredDirectoryService()) { self.service = service }
    func loadLanding() async { isLoading = true; error = nil; do { async let a = service.curatedCollections(); async let b = service.popularNearby(); async let c = service.popularDishes(); curated = try await a; popular = try await b; popularDishes = try await c } catch { if !Task.isCancelled { self.error = error.localizedDescription } }; isLoading = false }
    private var searchGeneration = UUID()
    func search() async {
        let generation = UUID(); searchGeneration = generation
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines); let selectedFilters = filters
        guard !term.isEmpty || selectedFilters != DirectoryFilters() else { results = []; error = nil; isLoading = false; return }
        isLoading = true; error = nil
        do {
            try await Task.sleep(for: .milliseconds(250))
            let found = try await service.search(query: term, filters: selectedFilters)
            try Task.checkCancellation()
            guard generation == searchGeneration else { return }
            results = found; isLoading = false
        } catch {
            guard generation == searchGeneration, !Task.isCancelled else { return }
            results = []; self.error = error.localizedDescription; isLoading = false
        }
    }

}

@MainActor @Observable final class ComposerStore {
    private let service: any DirectoryServing
    var restaurantQuery = ""; var restaurantResults: [DirectoryResult] = []; var selectedRestaurant: Restaurant?; var dishes = [PostDishDraftRequest(id: UUID(), dishID: nil, proposedName: "", rating: 4.5)]; var dishSuggestions: [UUID: [DirectoryResult]] = [:]; var photos: [PhotoUploadDraft] = []; var caption = ""; var visitDate = Date(); var includesVisitDate = false; var isWorking = false; var error: String?; var success = false
    init(service: any DirectoryServing = UnconfiguredDirectoryService()) { self.service = service }
    var canPost: Bool { selectedRestaurant != nil && !photos.isEmpty && dishes.allSatisfy { $0.dishID != nil || !$0.proposedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } && dishes.allSatisfy { (0.5...5).contains($0.rating) && ($0.rating * 2).rounded() == $0.rating * 2 } }
    private var restaurantGeneration = UUID()
    private var dishGenerations: [UUID: UUID] = [:]
    func findRestaurants() async {
        let generation = UUID(); restaurantGeneration = generation
        let text = restaurantQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { restaurantResults = []; return }
        do {
            try await Task.sleep(for: .milliseconds(200))
            let found = try await service.search(query: text, filters: .init()).filter { $0.kind == .restaurant }
            guard !Task.isCancelled, restaurantGeneration == generation else { return }
            restaurantResults = found; error = nil
        } catch { if !Task.isCancelled && restaurantGeneration == generation { self.error = error.localizedDescription } }
    }
    func findDishes(for id: UUID, text: String) async {
        let generation = UUID(); dishGenerations[id] = generation
        guard let restaurant = selectedRestaurant, !text.isEmpty else { dishSuggestions[id] = []; return }
        do {
            try await Task.sleep(for: .milliseconds(200))
            let found = try await service.search(query: text, filters: .init()).filter { $0.kind == .dish && $0.restaurantID == restaurant.id }
            guard !Task.isCancelled, dishGenerations[id] == generation else { return }
            dishSuggestions[id] = found
        } catch { if !Task.isCancelled && dishGenerations[id] == generation { self.error = error.localizedDescription } }
    }
    func publish() async { guard canPost, let restaurantID = selectedRestaurant?.id else { error = PlumError.invalidPost.errorDescription; return }; isWorking = true; error = nil; success = false; do { var resolved = dishes; for index in resolved.indices where resolved[index].dishID == nil { let dish = try await service.createDish(restaurantID: restaurantID, name: resolved[index].proposedName); resolved[index].dishID = dish.id }; let dishIDs = Set(resolved.compactMap(\.dishID)); let mappedPhotos = photos.map { photo in var mapped = photo; if mapped.linkedDishIDs.isEmpty { mapped.linkedDishIDs = dishIDs }; return mapped }; try await service.createPost(.init(restaurantID: restaurantID, dishes: resolved, photos: mappedPhotos, caption: caption.isEmpty ? nil : caption, visitDate: includesVisitDate ? visitDate : nil)); success = true } catch { self.error = error.localizedDescription }; isWorking = false }
    func reset() { restaurantQuery = ""; restaurantResults = []; selectedRestaurant = nil; dishes = [.init(id: UUID(), dishID: nil, proposedName: "", rating: 4.5)]; dishSuggestions = [:]; photos = []; caption = ""; includesVisitDate = false; visitDate = .now; success = false }
}
