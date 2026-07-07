import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        Group {
            if !AppConfiguration.shared.isConfigured {
                ConfigurationRequiredView()
            } else if authStore.isLoading {
                ProgressView("Restoring your session…")
            } else if authStore.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .task { await authStore.observeSession() }
    }
}

private struct ConfigurationRequiredView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Configuration Required", systemImage: "wrench.and.screwdriver")
        } description: {
            Text("Add the public Supabase URL, anon key, and FastAPI URL to AppConfig.plist.")
        }
        .padding()
    }
}
