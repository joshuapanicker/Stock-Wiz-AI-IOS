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
                screenerBackground
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
                    .padding(.bottom, 32)
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

    private var screenerBackground: some View {
        ZStack(alignment: .top) {
            DS.Color.background.ignoresSafeArea()
            DS.Gradient.ambientGreen().frame(height: 430).ignoresSafeArea()
            DS.Gradient.ambientViolet().frame(height: 600).ignoresSafeArea()
            DS.Gradient.ambientSky(opacity: 0.04).frame(height: 350).ignoresSafeArea()
        }
    }

    private var marketStrip: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle().fill(market?.marketTrend == "bullish" ? Color.green : Color.orange).frame(width: 7, height: 7)
                Text(market?.marketTrend.capitalized ?? "Market").fontWeight(.semibold)
            }
            Spacer()
            marketPill("SPY", ValueFormatting.currency(market?.spyLatest), color: .primary)
            marketPill("VIX", ValueFormatting.number(market?.vix, digits: 2), color: (market?.vix ?? 0) > 20 ? .orange : .green)
        }
        .font(.caption.monospaced()).padding(.horizontal, 13).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule()).overlay(Capsule().stroke(DS.Color.border)).padding(.top, 8)
    }

    private func marketPill(_ label: String, _ value: String, color: Color) -> some View {
        HStack(spacing: 4) { Text(label).foregroundStyle(.secondary); Text(value).foregroundStyle(color).fontWeight(.semibold) }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("DISCOVER")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(DS.Color.accent)
                    // Bold tracked headline — same family as DISCOVER label, scaled up
                    Text("Build a screen\nfrom an idea.")
                        .font(.system(size: 27, weight: .bold))
                        .tracking(-0.3)
                        .foregroundStyle(DS.Color.textPrimary)
                }
                Spacer(minLength: 12)
                ZStack {
                    Circle().fill(AngularGradient(colors: [DS.Color.accent.opacity(0.38), DS.Color.violet.opacity(0.18), DS.Color.amber.opacity(0.12), DS.Color.accent.opacity(0.38)], center: .center))
                    Circle().fill(DS.Color.background).padding(5)
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.title2).foregroundStyle(DS.Color.accent)
                }.frame(width: 60, height: 60).shadow(color: DS.Color.accent.opacity(0.2), radius: 15)
            }

            Text("Describe what you're looking for and StockWiz turns it into ranked results.")
                .font(.caption.monospaced())
                .foregroundStyle(DS.Color.textSecondary)
                .lineSpacing(4)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass").foregroundStyle(DS.Color.accent)
                TextField("Try: profitable software under 25 P/E", text: Bindable(model).query, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .font(.caption.monospaced())
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
                }.disabled(model.query.trimmingCharacters(in: .whitespaces).isEmpty || model.isSearching)
            }
            .padding(13)
            .background(DS.Color.background.opacity(0.8), in: RoundedRectangle(cornerRadius: DS.Radius.large))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.large).stroke(DS.Color.accent.opacity(0.24)))
        }
        .padding(.horizontal, 4)
    }

    private var promptChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(prompts.enumerated()), id: \.element) { index, prompt in
                    Button { Task { await model.search(prompt) } } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: ["cpu", "cross.case", "chart.line.uptrend.xyaxis", "building.columns", "cart", "bolt"][index])
                            .foregroundStyle([DS.Color.accent, DS.Color.violet, DS.Color.sky, DS.Color.amber, DS.Color.mint, DS.Color.rose][index % 6])
                            Text(prompt).font(.caption.weight(.medium)).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                        }
                        .frame(width: 142, height: 64, alignment: .leading).padding(12)
                        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.medium)).overlay(RoundedRectangle(cornerRadius: DS.Radius.medium).stroke(DS.Color.border))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var searching: some View {
        HStack(spacing: 10) {
            ProgressView().tint(.green)
            Text("Agent is filtering the stock universe…")
            Spacer()
        }
        .font(.subheadline)
        .dashboardCard()
    }

    private func errorCard(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Search failed", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text(error).font(.caption).foregroundStyle(.secondary)
            Button("Try Again") { Task { await model.search() } }.tint(.green)
        }
        .dashboardCard()
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Label("Intelligence brief", systemImage: "sparkles").font(.caption.bold()).foregroundStyle(.green); Spacer(); Text("AI GENERATED").font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(.tertiary) }
            Text(model.summary).font(.subheadline).lineSpacing(3)
        }
        .dashboardCard()
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
                            .foregroundStyle(.green)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.green.opacity(0.1), in: Capsule())
                            .overlay(Capsule().stroke(Color.green.opacity(0.25)))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var signalResults: some View {
        if !model.signals.isEmpty && model.query.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TODAY'S SIGNAL BOARD").font(.caption.bold()).tracking(1.2).foregroundStyle(.secondary)
                        Text("Personalized to your saved strategy").font(.caption2).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    HStack(spacing: 5) { Circle().fill(.green).frame(width: 5, height: 5); Text("LIVE").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.green) }
                    Button { Task { await model.loadSignals() } } label: { Image(systemName: "arrow.clockwise").font(.caption).padding(8).background(Color.white.opacity(0.06), in: Circle()) }
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
                    Text("MATCHES").font(.caption.bold()).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(model.totalMatched) stocks").font(.caption).foregroundStyle(.secondary)
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
                    DSBadge(signal.classification.uppercased(), color: accent)
                }
            }
            HStack(spacing: 10) {
                metric("FWD P/E",  ValueFormatting.number(signal.metrics.forwardPE))
                metric("GROWTH",   ValueFormatting.percent(signal.metrics.revenueGrowth))
                metric("MARGIN",   ValueFormatting.percent(signal.metrics.profitMargin))
                Spacer(minLength: 0)
                Text("\(result.rulesMet)/\(result.rulesTotal)")
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(accent)
            }
        }
        .padding(15)
        .background(
            LinearGradient(colors: [accent.opacity(0.07), DS.Color.surface], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: DS.Radius.large)
        )
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.large).stroke(accent.opacity(0.18)))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 8, weight: .bold)).tracking(0.7).foregroundStyle(DS.Color.textTertiary)
            Text(value).font(.caption2.monospaced()).foregroundStyle(DS.Color.textSecondary)
        }
    }
}

private extension View {
    func dashboardCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.large))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.large).stroke(DS.Color.border))
    }
}
