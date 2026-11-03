import Foundation
import Observation

enum DirectorySearchKind: String, CaseIterable, Identifiable, Sendable { case restaurant, dish, user, collection; var id: String { rawValue } }
struct DirectoryFilters: Equatable, Sendable { var cuisine: String?; var neighborhood: String?; var priceLevel: Int? }
struct DirectoryResult: Identifiable, Hashable, Sendable { let id: UUID; let kind: DirectorySearchKind; let title: String; let subtitle: String; let priceLevel: Int?; let restaurantID: UUID?; let isExactMatch: Bool }
struct PostDishDraftRequest: Identifiable, Sendable { let id: UUID; var dishID: UUID?; var proposedName: String; var rating: Double }
struct PhotoUploadDraft: Identifiable, Sendable { let id: UUID; let data: Data; let contentType: String; var linkedDishIDs: Set<UUID> }
struct PostDraftRequest: Sendable { let restaurantID: UUID; let dishes: [PostDishDraftRequest]; let photos: [PhotoUploadDraft]; let caption: String?; let visitDate: Date? }

protocol DirectoryServing: Sendable {
    func search(query: String, filters: DirectoryFilters) async throws -> [DirectoryResult]
    func curatedCollections() async throws -> [DirectoryResult]
    func popularNearby() async throws -> [DirectoryResult]
    func createDish(restaurantID: UUID, name: String) async throws -> Dish
    func createPost(_ draft: PostDraftRequest) async throws
}
struct UnconfiguredDirectoryService: DirectoryServing {
    func search(query: String, filters: DirectoryFilters) async throws -> [DirectoryResult] { throw PlumError.unavailable }
    func curatedCollections() async throws -> [DirectoryResult] { throw PlumError.unavailable }
    func popularNearby() async throws -> [DirectoryResult] { throw PlumError.unavailable }
    func createDish(restaurantID: UUID, name: String) async throws -> Dish { throw PlumError.unavailable }
    func createPost(_ draft: PostDraftRequest) async throws { throw PlumError.unavailable }
}

@MainActor @Observable final class ExploreStore {
    private let service: any DirectoryServing
    var query = ""; var filters = DirectoryFilters(); var results: [DirectoryResult] = []; var curated: [DirectoryResult] = []; var popular: [DirectoryResult] = []; var isLoading = false; var error: String?
    init(service: any DirectoryServing = UnconfiguredDirectoryService()) { self.service = service }
    func loadLanding() async { isLoading = true; error = nil; do { async let a = service.curatedCollections(); async let b = service.popularNearby(); curated = try await a; popular = try await b } catch { self.error = error.localizedDescription }; isLoading = false }
    func search() async { let term = query.trimmingCharacters(in: .whitespacesAndNewlines); guard !term.isEmpty || filters != DirectoryFilters() else { results = []; return }; isLoading = true; error = nil; do { results = try await service.search(query: term, filters: filters) } catch { results = []; self.error = error.localizedDescription }; isLoading = false }
}

@MainActor @Observable final class ComposerStore {
    private let service: any DirectoryServing
    var restaurantQuery = ""; var restaurantResults: [DirectoryResult] = []; var selectedRestaurant: Restaurant?; var dishes = [PostDishDraftRequest(id: UUID(), dishID: nil, proposedName: "", rating: 4.5)]; var dishSuggestions: [UUID: [DirectoryResult]] = [:]; var photos: [PhotoUploadDraft] = []; var caption = ""; var visitDate = Date(); var includesVisitDate = false; var isWorking = false; var error: String?; var success = false
    init(service: any DirectoryServing = UnconfiguredDirectoryService()) { self.service = service }
    var canPost: Bool { selectedRestaurant != nil && !photos.isEmpty && dishes.allSatisfy { $0.dishID != nil || !$0.proposedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } && dishes.allSatisfy { (0.5...5).contains($0.rating) && ($0.rating * 2).rounded() == $0.rating * 2 } }
    func findRestaurants() async { guard !restaurantQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { restaurantResults = []; return }; do { restaurantResults = try await service.search(query: restaurantQuery, filters: .init()).filter { $0.kind == .restaurant } } catch { self.error = error.localizedDescription } }
    func findDishes(for id: UUID, text: String) async { guard let restaurant = selectedRestaurant, !text.isEmpty else { dishSuggestions[id] = []; return }; do { dishSuggestions[id] = try await service.search(query: text, filters: .init()).filter { $0.kind == .dish && $0.restaurantID == restaurant.id } } catch { self.error = error.localizedDescription } }
    func publish() async { guard canPost, let restaurantID = selectedRestaurant?.id else { error = PlumError.invalidPost.errorDescription; return }; isWorking = true; error = nil; do { var resolved = dishes; for index in resolved.indices where resolved[index].dishID == nil { let dish = try await service.createDish(restaurantID: restaurantID, name: resolved[index].proposedName); resolved[index].dishID = dish.id }; try await service.createPost(.init(restaurantID: restaurantID, dishes: resolved, photos: photos, caption: caption.isEmpty ? nil : caption, visitDate: includesVisitDate ? visitDate : nil)); success = true } catch { self.error = error.localizedDescription }; isWorking = false }
    func reset() { restaurantQuery = ""; restaurantResults = []; selectedRestaurant = nil; dishes = [.init(id: UUID(), dishID: nil, proposedName: "", rating: 4.5)]; dishSuggestions = [:]; photos = []; caption = ""; includesVisitDate = false; visitDate = .now; success = false }
}
