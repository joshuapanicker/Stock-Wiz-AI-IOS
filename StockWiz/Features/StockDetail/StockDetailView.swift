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
    var metrics: StockMetrics?
    var analysis: AnalysisResult?
    var news: StockNews?
    var financials: Financials?
    var isLoading = true
    var isLoadingHistory = false
    var errorMessage: String?
    /// Price captured from the search/list row the user tapped — shown
    /// instantly while live data loads.
    var seededPrice: Double?

    init(symbol: String, action: String = "buy") {
        self.symbol = symbol.uppercased()
        self.action = action
        self.seededPrice = QuoteSeed.price(for: symbol)
    }

    /// Fast metrics (separate endpoint) arrive well before the AI analysis,
    /// so prefer them and fall back to the analysis payload.
    var displayMetrics: StockMetrics? { metrics ?? analysis?.metrics }

    var displayPrice: Double? {
        displayMetrics?.closePrice ?? history.last?.close ?? seededPrice
    }

    func load() async {
        isLoading = false
        errorMessage = nil
        isLoadingHistory = history.isEmpty
        await withTaskGroup(of: Void.self) { group in
            group.addTask { let v = try? await APIClient.shared.history(symbol: self.symbol, period: self.period); await MainActor.run { self.history = v ?? []; self.isLoadingHistory = false } }
            group.addTask { let v = try? await APIClient.shared.metrics(symbol: self.symbol); await MainActor.run { self.metrics = v } }
            group.addTask { let v = try? await APIClient.shared.analysis(symbol: self.symbol, action: self.action); await MainActor.run { self.analysis = v } }
            group.addTask { let v = try? await APIClient.shared.news(symbol: self.symbol); await MainActor.run { self.news = v } }
            group.addTask { let v = try? await APIClient.shared.financials(symbol: self.symbol); await MainActor.run { self.financials = v } }
            group.addTask { let v = try? await APIClient.shared.history(symbol: "SPY", period: self.period); await MainActor.run { self.benchmark = v ?? [] } }
        }
        isLoadingHistory = false
        if analysis == nil && metrics == nil && history.isEmpty {
            errorMessage = "We couldn't load \(symbol). Check your connection and try again."
        }
    }

    func loadHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        async let stockValue  = try? APIClient.shared.history(symbol: symbol, period: period)
        async let benchmarkValue = try? APIClient.shared.history(symbol: "SPY", period: period)
        history   = await stockValue ?? []
        benchmark = await benchmarkValue ?? []
    }
}

struct StockDetailView: View {
    @State private var model: StockDetailModel
    @State private var selectedDate: Date?
    @State private var selectedSection: DetailSection = .overview
    @State private var selectedPeriod = "1Y"
    @State private var showingSellSheet = false
    @AppStorage("stockChartType") private var storedChartType = StockChartType.area.rawValue

    private enum DetailSection: String, CaseIterable, Identifiable {
        case overview  = "Overview"
        case news      = "News"
        case financials = "Financials"
        case ai        = "Analysis"
        case chat      = "Chat"
        var id: Self { self }
    }

    private let periodOptions = ["1M", "3M", "6M", "1Y", "2Y"]
    private let periodMap    = ["1M": "1mo", "3M": "3mo", "6M": "6mo", "1Y": "1y", "2Y": "2y"]

    init(symbol: String, action: String = "buy") {
        _model = State(initialValue: StockDetailModel(symbol: symbol, action: action))
        // When opened from portfolio for sell analysis, land on the Analysis tab
        _selectedSection = State(initialValue: action == "sell" ? .ai : .overview)
    }

    var body: some View {
        ZStack(alignment: .top) {
            DS.Color.background.ignoresSafeArea()
            DS.Gradient.ambientGreen(opacity: 0.10).frame(height: 400).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                if model.isLoading {
                    loadingView
                } else if let error = model.errorMessage {
                    errorView(error)
                } else {
                    content
                }
            }
            .padding(.bottom, 80)
        }
        .navigationTitle(model.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .refreshable { await model.load() }
        .toolbar {
            if model.action == "sell" {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSellSheet = true
                    } label: {
                        Text("Sell")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.Color.background)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(DS.Color.amber, in: Capsule())
                    }
                }
            }
        }
        .sheet(isPresented: $showingSellSheet) {
            // Build a fake PortfolioHolding shell just to reuse SellHoldingSheet
            // We only need symbol + currentPrice for the sell flow
            SellFromDetailSheet(
                symbol: model.symbol,
                currentPrice: model.displayPrice
            )
        }
    }

    // MARK: Loading
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(DS.Color.accent)
            Text("Loading \(model.symbol)…")
                .foregroundStyle(DS.Color.textSecondary)
            Text("AI analysis can take a moment.")
                .font(.caption)
                .foregroundStyle(DS.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(DS.Color.warning)
            Text("Could not load \(model.symbol)")
                .font(.headline)
                .foregroundStyle(DS.Color.textPrimary)
            Text(error)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try Again") { Task { await model.load() } }
                .font(.subheadline.bold())
                .foregroundStyle(DS.Color.background)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(DS.Color.accent, in: Capsule())
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: Main content
    private var content: some View {
        VStack(spacing: 16) {
            header
            priceChart
            sectionPicker
            sectionContent
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: Header
    private var header: some View {
        let card = VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(DS.Color.textSecondary)
                    Text(ValueFormatting.currency(model.displayPrice))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Color.textPrimary)
                }
                Spacer()
                classificationBadge
            }

            if let metrics = model.displayMetrics {
                HStack(spacing: 8) {
                    if let sector = metrics.sector {
                        DSBadge(sector, color: DS.Color.sky)
                    }
                    if let industry = metrics.industry {
                        Text(industry)
                            .font(.caption2)
                            .foregroundStyle(DS.Color.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("Updated \(metrics.date)")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textTertiary)
                }
            }
        }

        return Group {
            if model.action == "sell" {
                card.dsSellHeroCard()
            } else {
                card.dsHeroCard()
            }
        }
    }

    @ViewBuilder
    private var classificationBadge: some View {
        // Don't show a misleading default badge while the analysis is loading
        if let result = model.analysis?.criteriaResult {
            let isBuy  = result.passed
            let label  = model.action == "sell"
                ? (isBuy ? "SELL" : "HOLD")
                : (isBuy ? "BUY"  : "WATCH")
            let color: Color = isBuy
                ? (model.action == "sell" ? DS.Color.loss : DS.Color.gain)
                : DS.Color.warning

            Text(label)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(color.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(color.opacity(0.3)))
        } else {
            ProgressView()
                .controlSize(.small)
                .tint(DS.Color.textTertiary)
        }
    }

    // MARK: Chart
    private var priceChart: some View {
        VStack(spacing: 14) {
            // Chart type + period row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedChart.label)
                        .font(.caption.bold())
                        .foregroundStyle(DS.Color.accent)
                    Text(selectedPriceLabel)
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textTertiary)
                }
                Spacer()
                chartTypeMenu
            }

            // Chart
            if model.isLoadingHistory {
                ProgressView()
                    .tint(DS.Color.accent)
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else if chartPoints.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundStyle(DS.Color.textTertiary)
                    Text("No price history")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                StockChartView(
                    type: selectedChart,
                    history: model.history,
                    benchmark: model.benchmark,
                    selectedDate: $selectedDate
                )
            }

            // Period pills
            DSPillPicker(options: periodOptions, selected: $selectedPeriod)
                .onChange(of: selectedPeriod) { _, newPeriod in
                    model.period = periodMap[newPeriod] ?? "1y"
                    selectedDate = nil
                    Task { await model.loadHistory() }
                }
        }
        .padding(16)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.xlarge))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.xlarge).stroke(DS.Color.border))
    }

    private var selectedChart: StockChartType {
        StockChartType(rawValue: storedChartType) ?? .area
    }

    private var chartTypeMenu: some View {
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
            HStack(spacing: 5) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                Text(selectedChart.label)
                    .font(.caption.bold())
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
            }
            .foregroundStyle(DS.Color.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DS.Color.background, in: Capsule())
            .overlay(Capsule().stroke(DS.Color.border))
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
            return "Drag across chart to inspect"
        }
        return "\(nearest.date.formatted(date: .abbreviated, time: .omitted))  ·  \(ValueFormatting.currency(nearest.close))"
    }

    // MARK: Section picker
    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(DetailSection.allCases) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selectedSection = section }
                    } label: {
                        Text(section.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selectedSection == section ? DS.Color.background : DS.Color.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(
                                selectedSection == section ? DS.Color.accent : DS.Color.surface,
                                in: Capsule()
                            )
                            .overlay(
                                selectedSection == section
                                    ? nil
                                    : Capsule().stroke(DS.Color.border)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Section content
    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .overview:   overview
        case .news:       news
        case .financials: financials
        case .ai:         aiAnalysis
        case .chat:       StockChatView(symbol: model.symbol)
        }
    }

    // MARK: Overview — shows sell criteria first when opened from portfolio
    private var overview: some View {
        VStack(spacing: 14) {
            if let metrics = model.displayMetrics {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    DSStatTile(icon: "arrow.down.to.line", label: "52-wk Low",     value: ValueFormatting.currency(metrics.low52Week))
                    DSStatTile(icon: "arrow.up.to.line",   label: "52-wk High",    value: ValueFormatting.currency(metrics.high52Week))
                    DSStatTile(icon: "building.2.fill",    label: "Market Cap",    value: ValueFormatting.compact(metrics.marketCap))
                    DSStatTile(icon: "chart.bar.fill",     label: "Trailing P/E",  value: ValueFormatting.number(metrics.trailingPE))
                    DSStatTile(icon: "chart.bar",          label: "Forward P/E",   value: ValueFormatting.number(metrics.forwardPE))
                    DSStatTile(icon: "arrow.up.right",     label: "Rev Growth",    value: ValueFormatting.percent(metrics.revenueGrowth))
                    DSStatTile(icon: "dollarsign.circle",  label: "Earn Growth",   value: ValueFormatting.percent(metrics.earningsGrowth))
                    DSStatTile(icon: "percent",            label: "Profit Margin", value: ValueFormatting.percent(metrics.profitMargin))
                }
            }
            criteriaCard
        }
    }

    private var criteriaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let result = model.analysis?.criteriaResult {
                let isSell = model.action == "sell"
                let title  = isSell ? "SELL CRITERIA" : "BUY CRITERIA"
                let passColor: Color = isSell
                    ? (result.passed ? DS.Color.loss : DS.Color.gain)
                    : (result.passed ? DS.Color.gain : DS.Color.warning)
                let passLabel: String = isSell
                    ? (result.passed ? "SELL" : "HOLD")
                    : (result.passed ? "BUY"  : "WATCH")

                HStack {
                    DSSectionHeader(title: title, subtitle: "\(result.rulesMet) of \(result.rulesTotal) conditions met")
                    Spacer()
                    DSBadge(passLabel, color: passColor)
                }
                VStack(spacing: 10) {
                    ForEach(result.details) { rule in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: rule.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(rule.passed
                                    ? (isSell ? DS.Color.loss : DS.Color.gain)
                                    : DS.Color.textTertiary)
                                .font(.system(size: 14))
                            Text(rule.description)
                                .font(.subheadline)
                                .foregroundStyle(rule.passed ? DS.Color.textPrimary : DS.Color.textSecondary)
                            Spacer()
                        }
                    }
                }
            }
        }
        .dsCard()
    }

    // MARK: News
    private var news: some View {
        VStack(spacing: 12) {
            if let earnings = model.news?.earnings {
                earningsCard(earnings)
            }
            if model.news?.headlines.isEmpty != false {
                VStack(spacing: 8) {
                    Image(systemName: "newspaper")
                        .font(.title2)
                        .foregroundStyle(DS.Color.textTertiary)
                    Text("No recent news")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(model.news?.headlines ?? []) { headline in
                    if let url = URL(string: headline.url), !headline.url.isEmpty {
                        Link(destination: url) { headlineCard(headline) }
                            .buttonStyle(.plain)
                    } else {
                        headlineCard(headline)
                    }
                }
            }
        }
    }

    private func earningsCard(_ earnings: Earnings) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DSSectionHeader(title: "LATEST EARNINGS")
            Text(earnings.quarter ?? "Recent quarter")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textPrimary)
            Text(earnings.beatMiss ?? "No surprise data")
                .font(.subheadline.bold())
                .foregroundStyle((earnings.surprisePercent ?? 0) >= 0 ? DS.Color.gain : DS.Color.loss)
        }
        .dsCard()
    }

    private func headlineCard(_ headline: Headline) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(headline.title)
                .font(.subheadline.bold())
                .foregroundStyle(DS.Color.textPrimary)
                .multilineTextAlignment(.leading)
            HStack {
                Text(headline.publisher)
                Text("·")
                Text(headline.age)
            }
            .font(.caption)
            .foregroundStyle(DS.Color.textSecondary)
        }
        .dsCard()
    }

    // MARK: Financials
    private var financials: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                DSStatTile(icon: "arrow.up.right",    label: "YoY Revenue",    value: ValueFormatting.percent(model.financials?.revenueGrowthYearOverYear))
                DSStatTile(icon: "percent",           label: "Profit Margin",  value: ValueFormatting.percent(model.financials?.profitMargin))
            }

            if let quarters = model.financials?.quarters, !quarters.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    DSSectionHeader(title: "QUARTERLY REVENUE")
                    Chart(quarters) { quarter in
                        if let revenue = quarter.revenue {
                            BarMark(
                                x: .value("Quarter", quarter.quarter),
                                y: .value("Revenue", revenue)
                            )
                            .foregroundStyle(DS.Color.accent.gradient)
                            .cornerRadius(4)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 5]))
                                .foregroundStyle(DS.Color.border)
                            AxisValueLabel()
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                    .chartXAxis {
                        AxisMarks {
                            AxisValueLabel()
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                    .frame(height: 220)
                }
                .dsCard()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.title2)
                        .foregroundStyle(DS.Color.textTertiary)
                    Text("No financial history")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
    }

    // MARK: AI Analysis — shows sell reasoning when action == "sell"
    private var aiAnalysis: some View {
        let isSell = model.action == "sell"
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(isSell ? "Sell Analysis" : "StockWiz Analysis", systemImage: isSell ? "arrow.down.circle.fill" : "sparkles")
                    .font(.subheadline.bold())
                    .foregroundStyle(isSell ? DS.Color.loss : DS.Color.accent)
                Spacer()
                DSBadge("AI", color: isSell ? DS.Color.loss : DS.Color.accent)
            }

            if isSell {
                // Brief sell signal summary before the full text
                if let result = model.analysis?.criteriaResult {
                    HStack(spacing: 8) {
                        Image(systemName: result.passed ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                            .foregroundStyle(result.passed ? DS.Color.loss : DS.Color.gain)
                        Text(result.passed
                             ? "\(result.rulesMet) of \(result.rulesTotal) sell conditions triggered — consider exiting"
                             : "Only \(result.rulesMet) of \(result.rulesTotal) sell conditions met — hold for now")
                            .font(.caption)
                            .foregroundStyle(result.passed ? DS.Color.loss : DS.Color.gain)
                    }
                    .padding(10)
                    .background((result.passed ? DS.Color.loss : DS.Color.gain).opacity(0.08),
                                 in: RoundedRectangle(cornerRadius: DS.Radius.small))
                }
            }

            Text(model.analysis?.analysisText ?? "Analysis is unavailable right now.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textPrimary)
                .lineSpacing(5)
                .textSelection(.enabled)

            Divider().background(DS.Color.border)
            Text("AI-generated content is not financial advice.")
                .font(.caption)
                .foregroundStyle(DS.Color.textTertiary)
        }
        .dsCard(radius: DS.Radius.xlarge)
    }
}

// MARK: - Sell From Detail Sheet
// Lightweight sell sheet launched from the stock analysis page.
// Uses the same API path as the portfolio sell, but doesn't need a full PortfolioHolding.
private struct SellFromDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let symbol: String
    let currentPrice: Double?

    @State private var sellPriceText: String
    @State private var sellDate = Date()
    @State private var isSelling = false
    @State private var didSell = false
    @State private var error: String?

    init(symbol: String, currentPrice: Double?) {
        self.symbol = symbol
        self.currentPrice = currentPrice
        _sellPriceText = State(initialValue: currentPrice.map { String(format: "%.2f", $0) } ?? "")
    }

    private var sellPrice: Double? { Double(sellPriceText) }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        if didSell {
                            // Success state
                            VStack(spacing: 14) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(DS.Color.accent)
                                Text("Sale Recorded")
                                    .font(.title3.bold())
                                    .foregroundStyle(DS.Color.textPrimary)
                                Text("\(symbol) has been moved to your trade history.")
                                    .font(.subheadline)
                                    .foregroundStyle(DS.Color.textSecondary)
                                    .multilineTextAlignment(.center)
                                Button("Done") { dismiss() }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(DS.Color.background)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(DS.Color.accent, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                            }
                            .padding(.top, 40)
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Record Sale — \(symbol)")
                                    .font(.title3.bold())
                                    .foregroundStyle(DS.Color.textPrimary)
                                Text("Enter the price you sold at to record this in your trade history.")
                                    .font(.subheadline)
                                    .foregroundStyle(DS.Color.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Sell Price per Share").font(.caption).foregroundStyle(DS.Color.textSecondary)
                                HStack {
                                    Text("$").foregroundStyle(DS.Color.textSecondary)
                                    TextField("0.00", text: $sellPriceText).keyboardType(.decimalPad)
                                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(DS.Color.textPrimary)
                                }
                                .padding(14)
                                .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                                .overlay(RoundedRectangle(cornerRadius: DS.Radius.medium).stroke(DS.Color.amber.opacity(0.3)))
                            }

                            DatePicker("Sell Date", selection: $sellDate, displayedComponents: .date)
                                .foregroundStyle(DS.Color.textPrimary)

                            if let error {
                                Text(error).font(.caption).foregroundStyle(DS.Color.loss)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                guard let price = sellPrice, !isSelling else { return }
                                let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                                isSelling = true
                                Task {
                                    do {
                                        try await APIClient.shared.sellHolding(
                                            symbol: symbol,
                                            sellPrice: price,
                                            sellDate: fmt.string(from: sellDate)
                                        )
                                        withAnimation { didSell = true }
                                    } catch {
                                        let msg = error.localizedDescription
                                        if msg.contains("404") || msg.lowercased().contains("not found")
                                            || msg.lowercased().contains("missing") {
                                            withAnimation { didSell = true }
                                        } else {
                                            self.error = msg
                                            isSelling = false
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    if isSelling { ProgressView().tint(DS.Color.background).controlSize(.small) }
                                    else { Text("Confirm Sale").font(.system(size: 16, weight: .semibold)).foregroundStyle(DS.Color.background) }
                                    Spacer()
                                }
                                .frame(height: 50)
                                .background(sellPrice != nil ? DS.Color.amber : DS.Color.surface,
                                             in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                            }
                            .disabled(sellPrice == nil || isSelling)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Record Sale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
