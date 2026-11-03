import Foundation

enum SupabaseConfigurationError: LocalizedError {
    case missingURL
    case missingPublishableKey

    var errorDescription: String? {
        switch self {
        case .missingURL:
            "Supabase is not configured. Add SUPABASE_URL to Config/Secrets.xcconfig."
        case .missingPublishableKey:
            "Supabase is not configured. Add the publishable key to Config/Secrets.xcconfig."
        }
    }
}

struct SupabaseConfiguration: Sendable {
    let url: URL
    let publishableKey: String

    static func load(bundle: Bundle = .main) throws -> Self {
        guard let string = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !string.isEmpty,
              let url = URL(string: string) else {
            throw SupabaseConfigurationError.missingURL
        }
        guard let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              !key.isEmpty else {
            throw SupabaseConfigurationError.missingPublishableKey
        }
        return Self(url: url, publishableKey: key)
    }
}
