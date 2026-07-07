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
            Color(red: 0.025, green: 0.03, blue: 0.037).ignoresSafeArea()
            RadialGradient(colors: [Color.green.opacity(0.13), .clear], center: UnitPoint(x: 0.12, y: 0.02), startRadius: 5, endRadius: 340).frame(height: 430).ignoresSafeArea()
            RadialGradient(colors: [Color.cyan.opacity(0.07), .clear], center: UnitPoint(x: 0.94, y: 0.25), startRadius: 5, endRadius: 260).frame(height: 600).ignoresSafeArea()
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
        .background(.ultraThinMaterial, in: Capsule()).overlay(Capsule().stroke(Color.white.opacity(0.08))).padding(.top, 8)
    }

    private func marketPill(_ label: String, _ value: String, color: Color) -> some View {
        HStack(spacing: 4) { Text(label).foregroundStyle(.secondary); Text(value).foregroundStyle(color).fontWeight(.semibold) }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Label("AI SCREENER", systemImage: "sparkles").font(.caption2.bold()).tracking(1.5).foregroundStyle(.green); Spacer(); Text("DISCOVERY ENGINE  /  01").font(.system(size: 8, weight: .bold)).tracking(1.1).foregroundStyle(.tertiary) }
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Build a screen\nfrom an idea.").font(.system(size: 31, weight: .bold, design: .rounded)).tracking(-0.8)
                    Text("Describe the opportunity. StockWiz turns it into measurable filters and ranked candidates.").font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
                }
                Spacer(minLength: 8)
                ZStack { Circle().fill(AngularGradient(colors: [.green.opacity(0.38), .cyan.opacity(0.12), .green.opacity(0.38)], center: .center)); Circle().fill(Color(red: 0.045, green: 0.06, blue: 0.055)).padding(5); Image(systemName: "scope").font(.title2).foregroundStyle(.green) }.frame(width: 66, height: 66).shadow(color: .green.opacity(0.2), radius: 15)
            }
            HStack(spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass").foregroundStyle(.green)
                TextField("Try profitable software under 25 P/E", text: Bindable(model).query, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit { Task { await model.search() } }
                Button { Task { await model.search() } } label: {
                    Image(systemName: "arrow.up").font(.headline.bold()).frame(width: 35, height: 35).background(Color.green, in: Circle()).foregroundStyle(.black)
                }
                .disabled(model.query.trimmingCharacters(in: .whitespaces).isEmpty || model.isSearching)
            }
            .padding(13).background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.24)))
            HStack(spacing: 14) { Label("Natural language", systemImage: "text.bubble"); Label("Live universe", systemImage: "dot.radiowaves.left.and.right"); Label("Ranked results", systemImage: "list.number") }.font(.caption2).foregroundStyle(.secondary)
        }
        .padding(20)
        .background(LinearGradient(colors: [Color(red: 0.07, green: 0.105, blue: 0.09), Color(red: 0.055, green: 0.06, blue: 0.075)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(LinearGradient(colors: [Color.green.opacity(0.35), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))).shadow(color: Color.green.opacity(0.08), radius: 24, y: 12)
    }

    private var promptChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(prompts.enumerated()), id: \.element) { index, prompt in
                    Button { Task { await model.search(prompt) } } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: ["cpu", "cross.case", "chart.line.uptrend.xyaxis", "building.columns", "cart", "bolt"][index]).foregroundStyle(index.isMultiple(of: 2) ? .green : .cyan)
                            Text(prompt).font(.caption.weight(.medium)).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                        }
                        .frame(width: 142, height: 64, alignment: .leading).padding(12)
                        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.07)))
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
            Text("\(rank)").font(.caption.monospaced().bold()).foregroundStyle(.tertiary).frame(width: 24, height: 24).background(Color.white.opacity(0.04), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(stock.symbol).font(.headline.monospaced())
                Text(stock.sector ?? "Unknown sector").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(ValueFormatting.currency(stock.closePrice)).font(.subheadline.monospaced().bold())
                Text("Rev \(ValueFormatting.percent(stock.revenueGrowth)) · PE \(ValueFormatting.number(stock.forwardPE))")
                    .font(.caption2)
                    .foregroundStyle((stock.revenueGrowth ?? 0) >= 0 ? .green : .red)
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(15)
        .background(LinearGradient(colors: [Color.white.opacity(0.055), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.white.opacity(0.075)))
    }
}

private struct SignalStockCard: View {
    let rank: Int
    let signal: ScreenerSignal
    private var accent: Color { signal.classification == "buy" ? .green : .orange }
    private var result: CriteriaResult { signal.classification == "buy" ? signal.buyResult : signal.watchResult }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 11) {
                Text("\(rank)").font(.caption2.monospaced().bold()).foregroundStyle(.secondary).frame(width: 25, height: 25).background(Color.white.opacity(0.05), in: Circle())
                VStack(alignment: .leading, spacing: 3) { Text(signal.symbol).font(.headline.monospaced()); Text(signal.metrics.sector ?? "Unclassified").font(.caption2).foregroundStyle(.secondary) }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) { Text(ValueFormatting.currency(signal.metrics.closePrice)).font(.subheadline.monospaced().bold()); Text(signal.classification.uppercased()).font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(accent).padding(.horizontal, 8).padding(.vertical, 3).background(accent.opacity(0.1), in: Capsule()) }
            }
            HStack(spacing: 10) {
                metric("FWD P/E", ValueFormatting.number(signal.metrics.forwardPE))
                metric("GROWTH", ValueFormatting.percent(signal.metrics.revenueGrowth))
                metric("MARGIN", ValueFormatting.percent(signal.metrics.profitMargin))
                Spacer(minLength: 0)
                Text("\(result.rulesMet)/\(result.rulesTotal)").font(.caption.monospaced().bold()).foregroundStyle(accent)
            }
        }
        .padding(15).background(LinearGradient(colors: [accent.opacity(0.075), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(0.17)))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(title).font(.system(size: 8, weight: .bold)).tracking(0.7).foregroundStyle(.tertiary); Text(value).font(.caption2.monospaced()).foregroundStyle(.secondary) }
    }
}

private extension View {
    func dashboardCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(Color(red: 0.065, green: 0.068, blue: 0.083), in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.white.opacity(0.07)))
    }
}
