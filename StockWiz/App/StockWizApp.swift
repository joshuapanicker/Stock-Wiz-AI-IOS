import SwiftUI

@main
struct StockWizApp: App {
    @State private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
                .preferredColorScheme(.dark)
        }
    }
}

