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

            // Floating glass tab bar — icon-only, glow marks the active tab
            floatingTabBar
                .padding(.horizontal, 44)
                .padding(.bottom, 12)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial, in: Capsule())
        .background(DS.Color.background.opacity(0.55), in: Capsule())
        .overlay(Capsule().stroke(DS.Color.border))
        .shadow(color: .black.opacity(0.4), radius: 22, y: 10)
    }

    @ViewBuilder
    private func tabItem(index: Int, icon: String, label: String) -> some View {
        let isActive = selectedTab == index
        // AI Chat gets the violet accent; everything else pulses teal
        let accent: Color = index == 2 ? DS.Color.violet : DS.Color.accent
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: isActive ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isActive ? accent : DS.Color.textTertiary)
                    .shadow(color: isActive ? accent.opacity(0.65) : .clear, radius: 7)
                Circle()
                    .fill(isActive ? accent : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
