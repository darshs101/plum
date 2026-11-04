import Foundation

enum SupabaseConfigurationError: LocalizedError {
    case missingURL
    case missingPublishableKey
    case unsafeKey

    var errorDescription: String? {
        switch self {
        case .missingURL:
            "Supabase is not configured. Add SUPABASE_URL to Config/Secrets.xcconfig."
        case .missingPublishableKey:
            "Supabase is not configured. Add the publishable key to Config/Secrets.xcconfig."
        case .unsafeKey:
            "This app needs a publishable or anon key. Never put a service-role or secret key in the app."
        }
    }
}

struct SupabaseConfiguration: Sendable {
    let url: URL
    let publishableKey: String

    static func load(bundle: Bundle = .main) throws -> Self {
        guard let string = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !string.isEmpty,
              let url = URL(string: string), url.scheme == "https", url.host != nil,
              !string.contains("$(") else {
            throw SupabaseConfigurationError.missingURL
        }
        guard let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              !key.isEmpty, !key.contains("$(") else {
            throw SupabaseConfigurationError.missingPublishableKey
        }
        let jwtRole: String? = {
            let components = key.split(separator: ".")
            guard components.count == 3 else { return nil }
            let encoded = String(components[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            let padded = encoded.padding(toLength: ((encoded.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
            guard let data = Data(base64Encoded: padded),
                  let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return claims["role"] as? String
        }()
        if key.hasPrefix("sb_secret_") || jwtRole == "service_role" {
            throw SupabaseConfigurationError.unsafeKey
        }
        return Self(url: url, publishableKey: key)
    }
}
