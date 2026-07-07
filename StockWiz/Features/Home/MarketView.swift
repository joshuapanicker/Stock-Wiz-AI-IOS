import SwiftUI

struct MarketView: View {
    @State private var market: MarketContext?
    @State private var query = ""
    @State private var results: [StockSearchResult] = []
    @State private var isLoadingMarket = true
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let popularSymbols = ["AAPL", "MSFT", "NVDA", "AMZN", "GOOGL", "META"]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DS.Color.background.ignoresSafeArea()
                DS.Gradient.ambientGreen().frame(height: 450).ignoresSafeArea()
                DS.Gradient.ambientViolet().frame(height: 600).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        // Search bar
                        searchBar

                        if !query.isEmpty {
                            searchContent
                        } else {
                            marketContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Markets")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { StockDetailView(symbol: $0) }
            .refreshable { await loadMarket() }
            .task { await loadMarket() }
            .task(id: query) { await search() }
        }
    }

    // MARK: Search bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(DS.Color.textSecondary)
            TextField("Search symbol or company…", text: $query)
                .font(.subheadline)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Color.textTertiary)
                }
            }
        }
        .padding(13)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.large))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.large).stroke(DS.Color.border))
        .padding(.top, 4)
    }

    // MARK: Market Overview
    @ViewBuilder
    private var marketContent: some View {
        if let market {
            // Trend + key stats hero
            marketHero(market)
            // Moving averages card
            movingAveragesCard(market)
        } else if isLoadingMarket {
            loadingCard
        } else if let errorMessage {
            errorCard(errorMessage)
        }

        // Popular stocks
        popularSection
    }

    private func marketHero(_ market: MarketContext) -> some View {
        VStack(spacing: 0) {
            // Top row: trend badge + SPY price
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    DSSectionHeader(title: "MARKET OVERVIEW")
                    HStack(spacing: 8) {
                        Circle()
                            .fill(trendColor(market.marketTrend))
                            .frame(width: 8, height: 8)
                        Text(market.marketTrend.capitalized)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(trendColor(market.marketTrend))
                    }
                }
                Spacer()
                DSLiveDot()
            }

            Divider()
                .background(DS.Color.border)
                .padding(.vertical, 14)

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                marketStat("SPY", ValueFormatting.currency(market.spyLatest), color: DS.Color.textPrimary)
                marketStat("VIX", ValueFormatting.number(market.vix, digits: 2), color: (market.vix ?? 0) > 20 ? DS.Color.warning : DS.Color.gain)
            }
        }
        .dsHeroCard()
    }

    private func movingAveragesCard(_ market: MarketContext) -> some View {
        VStack(spacing: 14) {
            DSSectionHeader(title: "SPY MOVING AVERAGES")
            HStack(spacing: 12) {
                maStat("20-day MA", ValueFormatting.currency(market.spy20DMA))
                maStat("50-day MA", ValueFormatting.currency(market.spy50DMA))
            }
        }
        .dsCard()
    }

    private func marketStat(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func maStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(DS.Color.accent)
            Text("Loading live market data…")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .dsCard()
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Market data unavailable", systemImage: "wifi.exclamationmark")
                .foregroundStyle(DS.Color.loss)
                .font(.subheadline.bold())
            Text(message)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Button("Try Again") { Task { await loadMarket() } }
                .font(.caption.bold())
                .foregroundStyle(DS.Color.accent)
        }
        .dsCard()
    }

    private var popularSection: some View {
        VStack(spacing: 10) {
            DSSectionHeader(title: "POPULAR STOCKS")
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(popularSymbols, id: \.self) { symbol in
                NavigationLink(value: symbol) {
                    popularRow(symbol: symbol)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func popularRow(symbol: String) -> some View {
        HStack(spacing: 12) {
            // Symbol avatar
            ZStack {
                Circle()
                    .fill(DS.Color.accent.opacity(0.1))
                Circle()
                    .stroke(DS.Color.accent.opacity(0.2))
                Text(String(symbol.prefix(1)))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.Color.accent)
            }
            .frame(width: 38, height: 38)

            Text(symbol)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.Color.textPrimary)

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(DS.Color.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.medium).stroke(DS.Color.border))
    }

    // MARK: Search Results
    @ViewBuilder
    private var searchContent: some View {
        if isSearching {
            HStack(spacing: 10) {
                ProgressView().tint(DS.Color.accent)
                Text("Searching…").font(.subheadline).foregroundStyle(DS.Color.textSecondary)
                Spacer()
            }
            .dsCard()
        } else if results.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(DS.Color.textTertiary)
                Text("No results for \"\(query)\"")
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            DSSectionHeader(title: "RESULTS")
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(results) { stock in
                NavigationLink(value: stock.symbol) {
                    searchResultRow(stock)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func searchResultRow(_ stock: StockSearchResult) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(DS.Color.accent.opacity(0.1))
                Circle().stroke(DS.Color.accent.opacity(0.2))
                Text(String(stock.symbol.prefix(1)))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.Color.accent)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(stock.symbol)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.Color.textPrimary)
                Text(stock.sector ?? "Unknown sector")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(ValueFormatting.currency(stock.closePrice))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.Color.textPrimary)
                Text(ValueFormatting.compact(stock.marketCap))
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(DS.Color.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.medium).stroke(DS.Color.border))
    }

    // MARK: Helpers
    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "bullish": DS.Color.gain
        case "bearish": DS.Color.loss
        case "mixed":   DS.Color.warning
        default:        DS.Color.textSecondary
        }
    }

    private func loadMarket() async {
        isLoadingMarket = true
        errorMessage = nil
        do {
            market = try await APIClient.shared.market()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMarket = false
    }

    private func search() async {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { results = []; isSearching = false; return }
        isSearching = true
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        do { results = try await APIClient.shared.search(normalized) } catch { results = [] }
        isSearching = false
    }
}
