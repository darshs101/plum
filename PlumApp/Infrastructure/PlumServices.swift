import Supabase

/// A single client keeps Auth, REST, Storage, and Realtime on the same session.
enum PlumServices {
    static let client: SupabaseClient? = {
        guard let configuration = try? SupabaseConfiguration.load() else { return nil }
        return SupabaseClient(supabaseURL: configuration.url, supabaseKey: configuration.publishableKey, options: .init(auth: .init(emitLocalSessionAsInitialSession: true)))
    }()
    static let directory: any DirectoryServing = {
        guard let client else { return UnconfiguredDirectoryService() }
        return SupabaseDirectoryService(client: client)
    }()
}
