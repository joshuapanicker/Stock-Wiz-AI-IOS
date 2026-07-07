import Foundation

struct AppConfiguration: Sendable {
    static let shared = AppConfiguration()

    let apiBaseURL: URL?
    let supabaseURL: URL?
    let supabaseAnonKey: String

    var isConfigured: Bool {
        apiBaseURL != nil && supabaseURL != nil &&
        !supabaseAnonKey.isEmpty && !supabaseAnonKey.hasPrefix("YOUR_")
    }

    private init(bundle: Bundle = .main) {
        guard
            let url = bundle.url(forResource: "AppConfig", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else {
            apiBaseURL = nil
            supabaseURL = nil
            supabaseAnonKey = ""
            return
        }

        apiBaseURL = Self.validURL(values["APIBaseURL"])
        supabaseURL = Self.validURL(values["SupabaseURL"])
        supabaseAnonKey = values["SupabaseAnonKey"] ?? ""
    }

    private static func validURL(_ value: String?) -> URL? {
        guard let value, !value.contains("YOUR_") else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard
            let url = URL(string: normalized),
            let scheme = url.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            url.host != nil
        else { return nil }
        return url
    }
}
