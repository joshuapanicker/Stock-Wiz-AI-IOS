import Charts
import Observation
import SwiftUI

@MainActor
@Observable
private final class StockDetailModel {
    let symbol: String
    let action: String
    var period = "1y"
    var history: [PriceBar] = []
    var benchmark: [PriceBar] = []
    var analysis: AnalysisResult?
    var news: StockNews?
    var financials: Financials?
    var isLoading = true
    var isLoadingHistory = false
    var errorMessage: String?

    init(symbol: String, action: String = "buy") {
        self.symbol = symbol.uppercased()
        self.action = action
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        // Reveal the detail shell immediately, then progressively fill each
        // independent section as its request completes.
        isLoading = false
        await withTaskGroup(of: Void.self) { group in
            group.addTask { let value = try? await APIClient.shared.history(symbol: self.symbol, period: self.period); await MainActor.run { self.history = value ?? [] } }
            group.addTask { let value = try? await APIClient.shared.analysis(symbol: self.symbol, action: self.action); await MainActor.run { self.analysis = value } }
            group.addTask { let value = try? await APIClient.shared.news(symbol: self.symbol); await MainActor.run { self.news = value } }
            group.addTask { let value = try? await APIClient.shared.financials(symbol: self.symbol); await MainActor.run { self.financials = value } }
            group.addTask { let value = try? await APIClient.shared.history(symbol: "SPY", period: self.period); await MainActor.run { self.benchmark = value ?? [] } }
        }
        if analysis == nil && history.isEmpty {
            errorMessage = "We couldn’t load \(symbol). Check your connection and try again."
        }
    }

    func loadHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        async let stockValue = try? APIClient.shared.history(symbol: symbol, period: period)
        async let benchmarkValue = try? APIClient.shared.history(symbol: "SPY", period: period)
        history = await stockValue ?? []
        benchmark = await benchmarkValue ?? []
    }
}

struct StockDetailView: View {
    @State private var model: StockDetailModel
    @State private var selectedDate: Date?
    @State private var selectedSection: DetailSection = .overview
    @AppStorage("stockChartType") private var storedChartType = StockChartType.candlestick.rawValue

    private enum DetailSection: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case news = "News"
        case financials = "Financials"
        case ai = "Analysis"
        case chat = "Chat"
        var id: Self { self }
    }

    init(symbol: String, action: String = "buy") {
        _model = State(initialValue: StockDetailModel(symbol: symbol, action: action))
    }

    var body: some View {
        ScrollView {
            if model.isLoading {
                loadingView
            } else if let error = model.errorMessage {
                ContentUnavailableView {
                    Label("Stock unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") { Task { await model.load() } }
                }
                .padding(.top, 80)
            } else {
                content
            }
        }
        .navigationTitle(model.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading \(model.symbol)…")
            Text("AI analysis can take a few seconds.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private var content: some View {
        VStack(spacing: 16) {
            header
            priceChart

            Picker("Section", selection: $selectedSection) {
                ForEach(DetailSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch selectedSection {
            case .overview: overview
            case .news: news
            case .financials: financials
            case .ai: analysis
            case .chat: StockChatView(symbol: model.symbol)
            }
        }
        .padding(.vertical)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(ValueFormatting.currency(model.analysis?.metrics.closePrice ?? model.history.last?.close))
                    .font(.largeTitle.bold())
                    .fontDesign(.monospaced)
                Spacer()
                classificationBadge
            }
            if let metrics = model.analysis?.metrics {
                Text([metrics.sector, metrics.industry].compactMap { $0 }.joined(separator: " · "))
                    .foregroundStyle(.secondary)
                Text("Updated \(metrics.date)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private var classificationBadge: some View {
        let isBuy = model.analysis?.criteriaResult.passed == true
        let label = model.action == "sell" ? (isBuy ? "SELL" : "HOLD") : (isBuy ? "BUY" : "WATCH")
        return Text(label)
            .font(.caption.bold())
            .foregroundStyle(isBuy ? .green : .orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background((isBuy ? Color.green : Color.orange).opacity(0.15), in: Capsule())
    }

    private var priceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedChart.label).font(.caption.bold()).foregroundStyle(.green)
                    Text(selectedPriceLabel).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                chartMenu
                periodMenu
            }

            if model.isLoadingHistory {
                ProgressView().frame(maxWidth: .infinity, minHeight: 220)
            } else if chartPoints.isEmpty {
                ContentUnavailableView("No price history", systemImage: "chart.xyaxis.line")
                    .frame(minHeight: 220)
            } else {
                StockChartView(type: selectedChart, history: model.history, benchmark: model.benchmark, selectedDate: $selectedDate)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
    }

    private var selectedChart: StockChartType {
        StockChartType(rawValue: storedChartType) ?? .candlestick
    }

    private var chartMenu: some View {
        Menu {
            ForEach(StockChartType.allCases) { type in
                Button {
                    storedChartType = type.rawValue
                    selectedDate = nil
                } label: {
                    VStack(alignment: .leading) {
                        Text(type.label)
                        Text(type.description)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.caption.bold())
                .padding(7)
                .background(.quaternary, in: Circle())
        }
    }

    private var periodMenu: some View {
        Menu {
            ForEach(["1mo", "3mo", "6mo", "1y", "2y"], id: \.self) { period in
                Button(period.uppercased()) {
                    model.period = period
                    selectedDate = nil
                    Task { await model.loadHistory() }
                }
            }
        } label: {
            Text(model.period.uppercased())
                .font(.caption.bold())
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
        }
    }

    private var chartPoints: [(date: Date, close: Double)] {
        model.history.compactMap { bar in
            guard let date = bar.parsedDate else { return nil }
            return (date, bar.close)
        }
    }

    private var selectedPriceLabel: String {
        guard let selectedDate,
              let nearest = chartPoints.min(by: {
                  abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
              }) else {
            return "Drag across the chart to inspect"
        }
        return "\(nearest.date.formatted(date: .abbreviated, time: .omitted)) · \(ValueFormatting.currency(nearest.close))"
    }

    private var overview: some View {
        VStack(spacing: 16) {
            if let metrics = model.analysis?.metrics {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metricCard("52-week low", ValueFormatting.currency(metrics.low52Week))
                    metricCard("52-week high", ValueFormatting.currency(metrics.high52Week))
                    metricCard("Market cap", ValueFormatting.compact(metrics.marketCap))
                    metricCard("Trailing P/E", ValueFormatting.number(metrics.trailingPE))
                    metricCard("Forward P/E", ValueFormatting.number(metrics.forwardPE))
                    metricCard("Revenue growth", ValueFormatting.percent(metrics.revenueGrowth))
                    metricCard("Earnings growth", ValueFormatting.percent(metrics.earningsGrowth))
                    metricCard("Profit margin", ValueFormatting.percent(metrics.profitMargin))
                }
                .padding(.horizontal)
            }
            criteria
        }
    }

    private func metricCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).fontDesign(.monospaced)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var criteria: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let result = model.analysis?.criteriaResult {
                Text("Buy criteria · \(result.rulesMet)/\(result.rulesTotal) met")
                    .font(.headline)
                ForEach(result.details) { rule in
                    Label(rule.description, systemImage: rule.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(rule.passed ? .primary : .secondary)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
    }

    private var news: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let earnings = model.news?.earnings {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Latest earnings").font(.headline)
                    Text(earnings.quarter ?? "Recent quarter")
                    Text(earnings.beatMiss ?? "No surprise data")
                        .foregroundStyle((earnings.surprisePercent ?? 0) >= 0 ? .green : .red)
                }
                .cardStyle()
            }
            if model.news?.headlines.isEmpty != false {
                ContentUnavailableView("No recent news", systemImage: "newspaper")
            } else {
                ForEach(model.news?.headlines ?? []) { headline in
                    Group {
                        if let url = URL(string: headline.url), !headline.url.isEmpty {
                            Link(destination: url) { headlineRow(headline) }
                        } else {
                            headlineRow(headline)
                        }
                    }
                    .cardStyle()
                }
            }
        }
        .padding(.horizontal)
    }

    private func headlineRow(_ headline: Headline) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(headline.title).font(.headline).foregroundStyle(.primary)
            Text("\(headline.publisher) · \(headline.age)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var financials: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                metricCard("YoY revenue", ValueFormatting.percent(model.financials?.revenueGrowthYearOverYear))
                metricCard("Profit margin", ValueFormatting.percent(model.financials?.profitMargin))
            }
            if let quarters = model.financials?.quarters, !quarters.isEmpty {
                Chart(quarters) { quarter in
                    if let revenue = quarter.revenue {
                        BarMark(x: .value("Quarter", quarter.quarter), y: .value("Revenue", revenue))
                            .foregroundStyle(.green)
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 250)
                .cardStyle()
            } else {
                ContentUnavailableView("No financial history", systemImage: "chart.bar")
            }
        }
        .padding(.horizontal)
    }

    private var analysis: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("StockWiz AI analysis").font(.headline)
            Text(model.analysis?.analysisText ?? "Analysis is unavailable right now.")
                .textSelection(.enabled)
                .lineSpacing(5)
            Text("AI-generated information is not financial advice.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
        .padding(.horizontal)
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}
