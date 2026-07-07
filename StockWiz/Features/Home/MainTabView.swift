import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                AgentScreenerView()
                    .tag(0)
                    .toolbar(.hidden, for: .tabBar)

                PortfolioView()
                    .tag(1)
                    .toolbar(.hidden, for: .tabBar)

                MarketChatView()
                    .tag(2)
                    .toolbar(.hidden, for: .tabBar)

                ProfileView()
                    .tag(3)
                    .toolbar(.hidden, for: .tabBar)
            }

            // Custom floating tab bar
            floatingTabBar
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabItem(index: 0, icon: "square.grid.2x2", label: "Discover")
            tabItem(index: 1, icon: "briefcase.fill", label: "Portfolio")
            tabItem(index: 2, icon: "sparkles", label: "AI Chat")
            tabItem(index: 3, icon: "person.fill", label: "Profile")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.xxlarge))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xxlarge)
                .stroke(DS.Color.border)
        )
        .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
    }

    @ViewBuilder
    private func tabItem(index: Int, icon: String, label: String) -> some View {
        let isActive = selectedTab == index
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isActive ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isActive ? DS.Color.accent : DS.Color.textTertiary)
                Text(label)
                    .font(.system(size: 9, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? DS.Color.accent : DS.Color.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
