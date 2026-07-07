import Observation
import SwiftUI

@MainActor
@Observable
private final class AgentScreenerModel {
    var query = ""
    var results: [UniverseStock] = []
    var filters: UniverseFilters?
    var summary = ""
    var totalMatched = 0
    var signals: [ScreenerSignal] = []
    var isSearching = false
    var errorMessage: String?

    func loadSignals() async {
        signals = (try? await APIClient.shared.screenerSignals()) ?? []
        for signal in signals { QuoteSeed.seed(symbol: signal.symbol, price: signal.metrics.closePrice) }
    }

    func clear() {
        query = ""
        results = []
        filters = nil
        summary = ""
        totalMatched = 0
        errorMessage = nil
    }

    func search(_ text: String? = nil) async {
        let prompt = (text ?? query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isSearching else { return }
        query = prompt
        results = []
        filters = nil
        summary = ""
        errorMessage = nil
        isSearching = true
        defer { isSearching = false }

        do {
            let stream = try await APIClient.shared.streamAgent(query: prompt)
            for try await payload in stream {
                guard let data = payload.data(using: .utf8) else { continue }
                if let event = try? JSONDecoder().decode(AgentResultEvent.self, from: data) {
                    results = event.results
                    filters = event.filters
                    totalMatched = event.totalMatched
                    for stock in results { QuoteSeed.seed(symbol: stock.symbol, price: stock.closePrice) }
                } else if let token = try? JSONDecoder().decode(StreamToken.self, from: data) {
                    summary += token.token
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AgentScreenerView: View {
    @State private var model = AgentScreenerModel()
    @State private var market: MarketContext?

    private let prompts = [
        "Profitable tech stocks under PE 25",
        "Healthcare stocks near 52-week lows",
        "High growth stocks with positive margins",
        "Value stocks in Financial sector",
        "Large cap Consumer Defensive stocks",
        "Energy stocks with revenue growth"
    ]

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ZStack(alignment: .top) {
                DSAuroraBackground()
                ScrollView {
                    LazyVStack(spacing: 16) {
                        marketStrip
                        hero
                        promptChips
                        if model.isSearching { searching }
                        if let error = model.errorMessage { errorCard(error) }
                        if !model.summary.isEmpty { summaryCard }
                        filterChips
                        results
                        if model.results.isEmpty && !model.isSearching { signalResults }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { StockDetailView(symbol: $0) }
            .task {
                market = try? await APIClient.shared.market()
                await model.loadSignals()
            }
        }
    }

    // MARK: Market mood strip
    private var marketStrip: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Circle()
                    .fill(trendColor)
                    .frame(width: 7, height: 7)
                    .shadow(color: trendColor.opacity(0.8), radius: 4)
                Text(market?.marketTrend.capitalized ?? "Market")
                    .fontWeight(.bold)
                    .foregroundStyle(trendColor)
            }
            Spacer()
            marketPill("SPY", ValueFormatting.currency(market?.spyLatest), color: DS.Color.textPrimary)
            marketPill("VIX", ValueFormatting.number(market?.vix, digits: 2),
                       color: (market?.vix ?? 0) > 20 ? DS.Color.warning : DS.Color.accent)
        }
        .font(.caption.monospaced())
        .padding(.horizontal, 15).padding(.vertical, 11)
        .background(.ultraThinMaterial, in: Capsule())
        .background(DS.Color.glassFill, in: Capsule())
        .overlay(Capsule().stroke(DS.Color.border))
        .padding(.top, 8)
    }

    private var trendColor: Color {
        switch market?.marketTrend {
        case "bullish": DS.Color.accent
        case "bearish": DS.Color.rose
        default:        DS.Color.warning
        }
    }

    private func marketPill(_ label: String, _ value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(DS.Color.textSecondary)
            Text(value).foregroundStyle(color).fontWeight(.semibold)
        }
    }

    // MARK: Hero
    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("DISCOVER")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(DS.Color.accent)
                    Text("Build a screen\nfrom an idea.")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .tracking(-0.3)
                        .foregroundStyle(DS.Color.textPrimary)
                }
                Spacer(minLength: 12)
                ZStack {
                    Circle().fill(AngularGradient(colors: [DS.Color.accent.opacity(0.40), DS.Color.violet.opacity(0.22), DS.Color.sky.opacity(0.12), DS.Color.accent.opacity(0.40)], center: .center))
                    Circle().fill(DS.Color.background).padding(5)
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.title2).foregroundStyle(DS.Color.accent)
                }.frame(width: 60, height: 60).shadow(color: DS.Color.accent.opacity(0.25), radius: 15)
            }

            Text("Describe what you're looking for and StockWiz turns it into ranked results.")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .lineSpacing(4)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass").foregroundStyle(DS.Color.accent)
                TextField("Try: profitable software under 25 P/E", text: Bindable(model).query, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .font(.caption)
                    .onSubmit { Task { await model.search() } }
                    .foregroundStyle(DS.Color.textPrimary)
                if !model.query.isEmpty {
                    Button { model.clear() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(DS.Color.textTertiary)
                    }
                }
                Button { Task { await model.search() } } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.bold())
                        .frame(width: 34, height: 34)
                        .background(DS.Color.accent, in: Circle())
                        .foregroundStyle(DS.Color.background)
                        .shadow(color: DS.Color.accent.opacity(0.4), radius: 8)
                }.disabled(model.query.trimmingCharacters(in: .whitespaces).isEmpty || model.isSearching)
            }
            .padding(13)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.large))
            .background(DS.Color.background.opacity(0.45), in: RoundedRectangle(cornerRadius: DS.Radius.large))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.large).stroke(DS.Color.accent.opacity(0.26)))
        }
        .dsHeroCard()
    }

    // MARK: Prompt chips
    private var promptChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(prompts.enumerated()), id: \.element) { index, prompt in
                    Button { Task { await model.search(prompt) } } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: ["cpu", "cross.case", "chart.line.uptrend.xyaxis", "building.columns", "cart", "bolt"][index])
                                .foregroundStyle([DS.Color.accent, DS.Color.violet, DS.Color.sky, DS.Color.amber, DS.Color.mint, DS.Color.rose][index % 6])
                            Text(prompt).font(.caption.weight(.medium)).foregroundStyle(DS.Color.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                        }
                        .frame(width: 142, height: 64, alignment: .leading).padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                        .background(DS.Color.glassFill, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.medium).stroke(DS.Color.border))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var searching: some View {
        HStack(spacing: 10) {
            ProgressView().tint(DS.Color.accent)
            Text("Agent is filtering the stock universe…")
                .foregroundStyle(DS.Color.textSecondary)
            Spacer()
        }
        .font(.subheadline)
        .dsCard()
    }

    private func errorCard(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Search failed", systemImage: "exclamationmark.triangle.fill").foregroundStyle(DS.Color.rose)
            Text(error).font(.caption).foregroundStyle(DS.Color.textSecondary)
            Button("Try Again") { Task { await model.search() } }.tint(DS.Color.accent)
        }
        .dsCard()
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Intelligence brief", systemImage: "sparkles").font(.caption.bold()).foregroundStyle(DS.Color.violet)
                Spacer()
                Text("AI GENERATED").font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(DS.Color.textTertiary)
            }
            Text(model.summary).font(.subheadline).lineSpacing(3).foregroundStyle(DS.Color.textPrimary)
        }
        .dsCard()
    }

    @ViewBuilder
    private var filterChips: some View {
        if let filters = model.filters, !filters.labels.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button { model.clear() } label: {
                        Label("Clear", systemImage: "xmark")
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(.secondary)
                    ForEach(filters.labels, id: \.self) { label in
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(DS.Color.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(DS.Color.accent.opacity(0.1), in: Capsule())
                            .overlay(Capsule().stroke(DS.Color.accent.opacity(0.25)))
                    }
                }
            }
        }
    }

    // MARK: Signal board
    @ViewBuilder
    private var signalResults: some View {
        if !model.signals.isEmpty && model.query.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    DSSectionHeader(title: "TODAY'S SIGNAL BOARD",
                                    subtitle: "Personalized to your saved strategy")
                    Spacer()
                    DSLiveDot()
                    Button { Task { await model.loadSignals() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(DS.Color.border))
                    }
                }
                ForEach(Array(model.signals.enumerated()), id: \.element.id) { index, signal in
                    NavigationLink(value: signal.symbol) {
                        SignalStockCard(rank: index + 1, signal: signal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        if !model.results.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    DSSectionHeader(title: "MATCHES")
                    Spacer()
                    Text("\(model.totalMatched) stocks").font(.caption).foregroundStyle(DS.Color.textSecondary)
                }
                ForEach(Array(model.results.enumerated()), id: \.element.id) { index, stock in
                    NavigationLink(value: stock.symbol) {
                        UniverseStockRow(rank: index + 1, stock: stock)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct UniverseStockRow: View {
    let rank: Int
    let stock: UniverseStock

    var body: some View {
        HStack(spacing: 12) {
            // Logo with rank badge below it
            VStack(spacing: 2) {
                TickerLogo(symbol: stock.symbol, size: 38)
                Text("#\(rank)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .frame(width: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(stock.symbol).font(.headline.monospaced()).foregroundStyle(DS.Color.textPrimary)
                Text(stock.sector ?? "Unknown sector").font(.caption2).foregroundStyle(DS.Color.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(ValueFormatting.currency(stock.closePrice))
                    .font(.subheadline.monospaced().bold())
                    .foregroundStyle(DS.Color.textPrimary)
                Text("Rev \(ValueFormatting.percent(stock.revenueGrowth)) · PE \(ValueFormatting.number(stock.forwardPE))")
                    .font(.caption2)
                    .foregroundStyle((stock.revenueGrowth ?? 0) >= 0 ? DS.Color.gain : DS.Color.loss)
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(DS.Color.textTertiary)
        }
        .padding(15)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.large))
        .background(DS.Gradient.rowCard, in: RoundedRectangle(cornerRadius: DS.Radius.large))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.large).stroke(DS.Color.border))
    }
}

private struct SignalStockCard: View {
    let rank: Int
    let signal: ScreenerSignal
    private var accent: Color { signal.classification == "buy" ? DS.Color.gain : DS.Color.warning }
    private var result: CriteriaResult { signal.classification == "buy" ? signal.buyResult : signal.watchResult }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 11) {
                VStack(spacing: 2) {
                    TickerLogo(symbol: signal.symbol, size: 38)
                    Text("#\(rank)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent.opacity(0.7))
                }
                .frame(width: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(signal.symbol).font(.headline.monospaced()).foregroundStyle(DS.Color.textPrimary)
                    Text(signal.metrics.sector ?? "Unclassified").font(.caption2).foregroundStyle(DS.Color.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(ValueFormatting.currency(signal.metrics.closePrice))
                        .font(.subheadline.monospaced().bold())
                        .foregroundStyle(DS.Color.textPrimary)
                    DSBadge(signal.classification.uppercased(), color: accent,
                            solid: signal.classification == "buy")
                }
            }
            HStack(spacing: 10) {
                metric("FWD P/E",  ValueFormatting.number(signal.metrics.forwardPE))
                metric("GROWTH",   ValueFormatting.percent(signal.metrics.revenueGrowth))
                metric("MARGIN",   ValueFormatting.percent(signal.metrics.profitMargin))
                Spacer(minLength: 0)
                DSCriteriaRing(met: result.rulesMet, total: result.rulesTotal,
                               color: accent, size: 34)
            }
        }
        .padding(15)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.large))
        .background(
            LinearGradient(colors: [accent.opacity(0.09), DS.Color.glassFill],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: DS.Radius.large)
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.large).stroke(accent.opacity(0.20)))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 8, weight: .bold)).tracking(0.7).foregroundStyle(DS.Color.textTertiary)
            Text(value).font(.caption2.monospaced()).foregroundStyle(DS.Color.textSecondary)
        }
    }
}
