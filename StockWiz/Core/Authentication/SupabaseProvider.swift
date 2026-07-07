import Foundation
import Supabase

enum SupabaseProvider {
    static let client: SupabaseClient = {
        let configuration = AppConfiguration.shared
        // Placeholder values only keep previews/builds alive until AppConfig.plist is filled in.
        let url = configuration.supabaseURL ?? URL(string: "https://placeholder.supabase.co")!
        let key = configuration.supabaseAnonKey.isEmpty ? "placeholder" : configuration.supabaseAnonKey
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()
}

