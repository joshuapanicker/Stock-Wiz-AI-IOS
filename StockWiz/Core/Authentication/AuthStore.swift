import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class AuthStore {
    private(set) var session: Session?
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    var isAuthenticated: Bool { session != nil }

    func observeSession() async {
        guard AppConfiguration.shared.isConfigured else {
            isLoading = false
            return
        }
        for await (_, updatedSession) in SupabaseProvider.client.auth.authStateChanges {
            guard !Task.isCancelled else { return }
            session = updatedSession
            isLoading = false
        }
    }

    func signIn(email: String, password: String) async {
        await performAuth {
            try await SupabaseProvider.client.auth.signIn(email: email, password: password)
        }
    }

    func signUp(email: String, password: String) async {
        await performAuth {
            try await SupabaseProvider.client.auth.signUp(email: email, password: password).session
        }
    }

    func signOut() async {
        do {
            try await SupabaseProvider.client.auth.signOut()
            session = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performAuth(_ operation: () async throws -> Session?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            session = try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
