import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            AgentScreenerView()
                .tabItem { Label("Screener", systemImage: "chart.bar.xaxis") }
            PortfolioView()
                .tabItem { Label("Portfolio", systemImage: "briefcase") }
            MarketChatView()
                .tabItem { Label("AI Chat", systemImage: "bubble.left.and.bubble.right") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(.green)
    }
}

private struct PlaceholderView: View {
    let title: String
    let icon: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: icon, description: Text("Coming in the next milestone."))
                .navigationTitle(title)
        }
    }
}
