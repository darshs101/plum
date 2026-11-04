import Combine
import Foundation
import Supabase

@MainActor final class NotificationInboxStore: ObservableObject {
    static let shared = NotificationInboxStore()
    @Published private(set) var unreadCount = 0
    @Published private(set) var revision = 0
    @Published private(set) var error: String?
    private var userID: UUID?
    private var visibleViews: Set<UUID> = []
    private var pendingRefresh: Task<Void, Never>?

    func reset() {
        pendingRefresh?.cancel(); pendingRefresh = nil
        userID = nil; visibleViews.removeAll(); unreadCount = 0; error = nil
    }

    private func prepare(_ me: UUID) {
        if userID != me { reset(); userID = me }
    }

    func beginViewing(_ token: UUID) async {
        do {
            let me = try await PlumAPI.userID()
            guard !Task.isCancelled, PlumServices.client?.auth.currentSession?.user.id == me else { return }
            prepare(me); visibleViews.insert(token); await synchronize()
        }
        catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }

    func endViewing(_ token: UUID) { visibleViews.remove(token) }

    func synchronize() async {
        do {
            let me = try await PlumAPI.userID()
            guard !Task.isCancelled, PlumServices.client?.auth.currentSession?.user.id == me else { return }
            prepare(me)
            if !visibleViews.isEmpty { _ = try await PlumAPI.client.rpc("mark_notifications_viewed").execute() }
            let count = try await PlumAPI.client.from("notifications").select("id", head: true, count: .exact)
                .eq("recipient_id", value: me).is("read_at", value: nil).execute().count ?? 0
            guard !Task.isCancelled, userID == me, PlumServices.client?.auth.currentSession?.user.id == me else { return }
            unreadCount = count; error = nil; revision += 1
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }

    func listen() async {
        do {
            let me = try await PlumAPI.userID(); prepare(me)
            let realtime = try PlumAPI.client.realtimeV2
            let channel = realtime.channel("notifications-\(me)")
            defer { Task { await realtime.removeChannel(channel) } }
            let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "notifications", filter: "recipient_id=eq.\(me.uuidString)")
            try await channel.subscribeWithError()
            await synchronize()
            for await _ in changes {
                guard !Task.isCancelled else { return }
                // Coalesce a burst of read updates into one count/list refresh.
                pendingRefresh?.cancel()
                pendingRefresh = Task { [weak self] in
                    do { try await Task.sleep(for: .milliseconds(100)); await self?.synchronize() }
                    catch { /* Superseded by a newer event. */ }
                }
            }
        } catch { if !Task.isCancelled { await synchronize() } }
    }
}
