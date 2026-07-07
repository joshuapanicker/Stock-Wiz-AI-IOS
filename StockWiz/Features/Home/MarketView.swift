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
            List {
                if let market {
                    marketSection(market)
                } else if isLoadingMarket {
                    Section("Market pulse") {
                        ProgressView("Loading live market data…")
                    }
                } else if let errorMessage {
                    Section {
                        ContentUnavailableView(
                            "Market data unavailable",
                            systemImage: "wifi.exclamationmark",
                            description: Text(errorMessage)
                        )
                        Button("Try Again") { Task { await loadMarket() } }
                    }
                }

                if !query.isEmpty {
                    searchSection
                } else {
                    Section("Popular stocks") {
                        ForEach(popularSymbols, id: \.self) { symbol in
                            NavigationLink(value: symbol) {
                                Label(symbol, systemImage: "chart.line.uptrend.xyaxis")
                                    .fontDesign(.monospaced)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Markets")
            .searchable(text: $query, prompt: "Symbol, such as AAPL")
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .navigationDestination(for: String.self) { symbol in
                StockDetailView(symbol: symbol)
            }
            .refreshable { await loadMarket() }
            .task { await loadMarket() }
            .task(id: query) { await search() }
        }
    }

    @ViewBuilder
    private func marketSection(_ market: MarketContext) -> some View {
        Section("Market pulse") {
            HStack {
                Label("Trend", systemImage: trendIcon(market.marketTrend))
                Spacer()
                Text(market.marketTrend.capitalized)
                    .foregroundStyle(trendColor(market.marketTrend))
                    .fontWeight(.semibold)
            }
            LabeledContent("SPY", value: ValueFormatting.currency(market.spyLatest))
            LabeledContent("VIX", value: ValueFormatting.number(market.vix, digits: 2))
            LabeledContent("SPY 20-day average", value: ValueFormatting.currency(market.spy20DMA))
            LabeledContent("SPY 50-day average", value: ValueFormatting.currency(market.spy50DMA))
        }
    }

    @ViewBuilder
    private var searchSection: some View {
        Section("Search results") {
            if isSearching {
                ProgressView("Searching…")
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ForEach(results) { stock in
                    NavigationLink(value: stock.symbol) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(stock.symbol).fontWeight(.semibold).fontDesign(.monospaced)
                                Spacer()
                                Text(ValueFormatting.currency(stock.closePrice)).fontDesign(.monospaced)
                            }
                            HStack {
                                Text(stock.sector ?? "Unknown sector")
                                Spacer()
                                Text(ValueFormatting.compact(stock.marketCap))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "bullish": .green
        case "bearish": .red
        case "mixed": .orange
        default: .secondary
        }
    }

    private func trendIcon(_ trend: String) -> String {
        switch trend {
        case "bullish": "arrow.up.right"
        case "bearish": "arrow.down.right"
        default: "arrow.left.and.right"
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
        guard !normalized.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        do {
            results = try await APIClient.shared.search(normalized)
        } catch {
            results = []
        }
        isSearching = false
    }
}
