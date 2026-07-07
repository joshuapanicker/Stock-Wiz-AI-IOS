import Charts
import Observation
import SwiftUI

@MainActor @Observable
private final class PortfolioModel {
    var holdings: [PortfolioHolding] = []
    var soldPositions: [SoldPosition] = []
    var isLoading = true
    var error: String?

    var totalValue: Double { holdings.compactMap(\.totalValue).reduce(0, +) }
    var netGain: Double    { holdings.compactMap(\.gainAbsolute).reduce(0, +) }
    var totalRealized: Double { soldPositions.compactMap(\.realizedGain).reduce(0, +) }
    var sellSignalCount: Int { holdings.filter { $0.sellResult?.passed == true }.count }

    init() {
        if let data   = UserDefaults.standard.data(forKey: "cachedPortfolio"),
           let cached = try? JSONDecoder().decode([PortfolioHolding].self, from: data) {
            holdings  = cached; isLoading = false
        }
    }

    func load() async {
        isLoading = holdings.isEmpty; error = nil
        async let holdingsResult  = try? APIClient.shared.portfolio()
        async let soldResult      = try? APIClient.shared.soldPositions()
        if let h = await holdingsResult { holdings = h
            for holding in h { QuoteSeed.seed(symbol: holding.symbol, price: holding.currentPrice) }
            if let data = try? JSONEncoder().encode(h) {
                UserDefaults.standard.set(data, forKey: "cachedPortfolio")
            }
        }
        if let s = await soldResult { soldPositions = s }
        isLoading = false
    }

    func add(symbol: String, date: Date, price: Double?, shares: Double) async throws {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        try await APIClient.shared.addHolding(
            .init(symbol: symbol.uppercased(), buyDate: fmt.string(from: date),
                  buyPrice: price, shares: shares, notes: ""))
        await load()
    }

    func remove(_ symbol: String) async {
        holdings.removeAll { $0.symbol == symbol }
        try? await APIClient.shared.deleteHolding(symbol: symbol)
        await load()
    }

    func sell(_ symbol: String, price: Double, date: String) async throws {
        // 1. Remove from UI immediately — instant feedback, no waiting
        holdings.removeAll { $0.symbol == symbol }
        if let data = try? JSONEncoder().encode(holdings) {
            UserDefaults.standard.set(data, forKey: "cachedPortfolio")
        }
        // 2. Call API — ignore decoding errors (server returns varying shapes)
        //    Only propagate genuine network/auth failures
        do {
            try await APIClient.shared.sellHolding(symbol: symbol, sellPrice: price, sellDate: date)
        } catch {
            let msg = error.localizedDescription
            let isAlreadySold = msg.contains("404") || msg.lowercased().contains("not found")
            let isDecodeError = msg.lowercased().contains("missing") || msg.lowercased().contains("decod")
            // Treat 404 and decode errors as success — the sale went through
            if !isAlreadySold && !isDecodeError {
                throw error
            }
        }
        // 3. Reload sold positions in background to populate history
        if let sold = try? await APIClient.shared.soldPositions() {
            soldPositions = sold
        }
    }
}

struct PortfolioView: View {
    @State private var model = PortfolioModel()
    @State private var showingAdd = false
    @State private var showingBrokerage = false
    @State private var selected = Set<String>()
    @State private var sellTarget: PortfolioHolding?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DSAuroraBackground(
                    primary: model.netGain >= 0 ? DS.Color.accent : DS.Color.rose,
                    intensity: 0.9
                )
                Group {
                    if model.isLoading && model.holdings.isEmpty && model.soldPositions.isEmpty {
                        loadingView
                    } else if let error = model.error, model.holdings.isEmpty {
                        emptyState(icon: "wifi.exclamationmark", title: "Portfolio unavailable", subtitle: error)
                    } else {
                        portfolioContent
                    }
                }
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingBrokerage = true } label: {
                        Image(systemName: "building.columns")
                            .padding(8).background(DS.Color.surface, in: Circle())
                            .overlay(Circle().stroke(DS.Color.border))
                    }
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                            .padding(8).background(DS.Color.accent.opacity(0.15), in: Circle())
                            .overlay(Circle().stroke(DS.Color.accent.opacity(0.3)))
                            .foregroundStyle(DS.Color.accent)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddHoldingView { sym, date, price, shares in
                    try await model.add(symbol: sym, date: date, price: price, shares: shares)
                }
            }
            .sheet(isPresented: $showingBrokerage) { BrokerageSettingsView() }
            .sheet(item: $sellTarget) { holding in SellHoldingSheet(holding: holding) { price, date in
                try await model.sell(holding.symbol, price: price, date: date)
            }}
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }

    // MARK: Loading / Empty
    private var loadingView: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("Loading your portfolio…").font(.title3.bold()).foregroundStyle(DS.Color.textPrimary)
            ProgressView().tint(DS.Color.accent)
            ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: DS.Radius.large)
                .fill(DS.Color.surface).frame(height: 80).redacted(reason: .placeholder) }
        }.padding(16) }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(DS.Color.textTertiary)
            Text(title).font(.headline).foregroundStyle(DS.Color.textPrimary)
            Text(subtitle).font(.subheadline).foregroundStyle(DS.Color.textSecondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.top, 100).padding(.horizontal, 32)
    }

    // MARK: Main content
    private var portfolioContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                if model.holdings.isEmpty {
                    // No active positions — show a minimal empty card
                    VStack(spacing: 10) {
                        Image(systemName: "briefcase")
                            .font(.system(size: 36))
                            .foregroundStyle(DS.Color.textTertiary)
                        Text("No current positions")
                            .font(.headline)
                            .foregroundStyle(DS.Color.textPrimary)
                        Text("Add a stock or connect a brokerage to start tracking.")
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .padding(.horizontal, 32)
                } else {
                    portfolioHero
                    statsRow
                    performanceChart
                    allocationChart
                    selectionBar
                    holdingsSection
                }
                if !model.soldPositions.isEmpty { soldHistorySection }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: Hero
    private var portfolioHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("PORTFOLIO", systemImage: "waveform.path.ecg").font(.system(size: 10, weight: .bold))
                    .tracking(1.2).foregroundStyle(DS.Color.accent)
                Spacer(); DSLiveDot()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Value").font(.caption).foregroundStyle(DS.Color.textSecondary)
                Text(ValueFormatting.currency(model.totalValue))
                    .font(DS.Font.portfolioValue)
                    .foregroundStyle(DS.Color.textPrimary)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
            }
            HStack(spacing: 16) {
                Label("\(model.holdings.count) positions", systemImage: "square.stack.3d.up")
                    .font(.caption).foregroundStyle(DS.Color.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: model.netGain >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text((model.netGain >= 0 ? "+" : "") + ValueFormatting.currency(model.netGain))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(model.netGain >= 0 ? DS.Color.gain : DS.Color.loss)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background((model.netGain >= 0 ? DS.Color.gain : DS.Color.loss).opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke((model.netGain >= 0 ? DS.Color.gain : DS.Color.loss).opacity(0.25)))
            }
        }.dsHeroCard()
    }

    // MARK: Stats row — clearer sell signal label
    private var statsRow: some View {
        HStack(spacing: 10) {
            DSStatTile(icon: "arrow.up.right", label: "Net P&L",
                       value: ValueFormatting.currency(model.netGain),
                       accent: model.netGain >= 0 ? DS.Color.gain : DS.Color.loss)
            DSStatTile(icon: "exclamationmark.triangle",
                       label: "Meet sell criteria",
                       value: "\(model.sellSignalCount)",
                       accent: model.sellSignalCount > 0 ? DS.Color.warning : DS.Color.gain)
        }
    }

    // MARK: Performance chart
    private var performanceChart: some View {
        let points = combinedHistory
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                DSSectionHeader(title: "VALUE OVER TIME", subtitle: "Combined market value")
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(DS.Color.accent).font(.system(size: 14))
            }
            Chart(points, id: \.0) { point in
                AreaMark(x: .value("Date", point.0), y: .value("Value", point.1))
                    .foregroundStyle(LinearGradient(colors: [DS.Color.accent.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", point.0), y: .value("Value", point.1))
                    .foregroundStyle(DS.Color.accent).lineStyle(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { AxisValueLabel().foregroundStyle(DS.Color.textSecondary) } }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 5])).foregroundStyle(DS.Color.border)
                AxisValueLabel { if let amount = value.as(Double.self) { Text(compactCurrency(amount)).foregroundStyle(DS.Color.textSecondary) } }
            }}
            .chartPlotStyle { plot in plot.clipShape(RoundedRectangle(cornerRadius: 8)) }
            .frame(height: 180)
        }.dsCard()
    }

    /// Combined portfolio value over time.
    /// Starts at the first date where every holding has data (so the curve
    /// never fake-dips when one position has a shorter history) and carries
    /// each holding's last known price forward across missing dates.
    private var combinedHistory: [(String, Double)] {
        let histories = model.holdings.filter { !$0.history.isEmpty }
        guard !histories.isEmpty else { return [] }

        // Union of all dates, starting where every holding has begun trading
        let startDate = histories.compactMap { $0.history.first?.date }.max() ?? ""
        let allDates = Set(histories.flatMap { $0.history.map(\.date) })
            .filter { $0 >= startDate }
            .sorted()
        guard !allDates.isEmpty else { return [] }

        // Fast per-holding lookup, then walk dates carrying prices forward
        let priceMaps: [(shares: Double, prices: [String: Double])] = histories.map { h in
            (h.shares, Dictionary(h.history.map { ($0.date, $0.close) }, uniquingKeysWith: { _, new in new }))
        }
        var lastPrice = [Int: Double]()
        var points: [(String, Double)] = []
        for date in allDates {
            var total = 0.0
            for (idx, entry) in priceMaps.enumerated() {
                if let p = entry.prices[date] { lastPrice[idx] = p }
                total += (lastPrice[idx] ?? 0) * entry.shares
            }
            points.append((date, total))
        }
        return points
    }

    private func compactCurrency(_ v: Double) -> String {
        if abs(v) >= 1_000_000 { return "$\((v / 1_000_000).formatted(.number.precision(.fractionLength(1))))M" }
        if abs(v) >= 1_000 { return "$\((v / 1_000).formatted(.number.precision(.fractionLength(0))))K" }
        return "$\(v.formatted(.number.precision(.fractionLength(0))))"
    }

    // MARK: Allocation chart — donut with center total, top positions + Other
    private var allocationChart: some View {
        let total = model.holdings.compactMap(\.totalValue).reduce(0, +)
        var slices: [(String, Double, Double)] = model.holdings.compactMap { h in
            guard let tv = h.totalValue, total > 0 else { return nil }
            return (h.symbol, tv, (tv / total) * 100)
        }.sorted { $0.1 > $1.1 }

        // Bucket everything beyond the top 5 into "Other" so the donut and
        // legend always agree and small slivers stay readable
        if slices.count > 6 {
            let rest = slices.dropFirst(5)
            let restValue = rest.reduce(0) { $0 + $1.1 }
            slices = Array(slices.prefix(5))
            slices.append(("OTHER", restValue, total > 0 ? restValue / total * 100 : 0))
        }

        let colors: [Color] = DS.Color.chartPalette
        return VStack(alignment: .leading, spacing: 14) {
            DSSectionHeader(title: "ALLOCATION", subtitle: "By current market value")
            HStack(spacing: 18) {
                // Donut with center total
                ZStack {
                    Chart(Array(slices.enumerated()), id: \.offset) { idx, slice in
                        SectorMark(angle: .value("Value", slice.1),
                                   innerRadius: .ratio(0.68),
                                   angularInset: 1.5)
                            .foregroundStyle(colors[idx % colors.count])
                            .cornerRadius(3)
                    }
                    VStack(spacing: 1) {
                        Text(compactCurrency(total))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Color.textPrimary)
                            .minimumScaleFactor(0.6)
                        Text("TOTAL")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                    .frame(width: 78)
                }
                .frame(width: 132, height: 132)

                // Legend with aligned percentages
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(slices.enumerated()), id: \.offset) { idx, slice in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colors[idx % colors.count])
                                .frame(width: 8, height: 8)
                            Text(slice.0)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(slice.0 == "OTHER" ? DS.Color.textSecondary : DS.Color.textPrimary)
                            Spacer()
                            Text("\(slice.2.formatted(.number.precision(.fractionLength(1))))%")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }.frame(maxWidth: .infinity)
            }
        }.dsCard()
    }

    // MARK: Selection bar
    private var selectionBar: some View {
        HStack {
            Button(selected.count == model.holdings.count ? "Clear All" : "Select All") {
                selected = selected.count == model.holdings.count ? [] : Set(model.holdings.map(\.symbol))
            }.font(.subheadline).foregroundStyle(DS.Color.accent)
            Spacer()
            if !selected.isEmpty {
                Text("\(selected.count) selected").font(.caption).foregroundStyle(DS.Color.textSecondary)
                Button("Delete") {
                    let syms = selected; selected = []
                    Task { for s in syms { await model.remove(s) } }
                }.font(.subheadline.bold()).foregroundStyle(DS.Color.loss)
            }
        }.padding(.horizontal, 4)
    }

    // MARK: Holdings list — tapping navigates to SELL analysis
    private var holdingsSection: some View {
        VStack(spacing: 10) {
            HStack {
                DSSectionHeader(title: "POSITIONS")
                Spacer()
                Text("\(model.holdings.count) HOLDINGS").font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(DS.Color.textTertiary)
            }
            ForEach(model.holdings) { holdingRow($0) }
        }
    }

    private func holdingRow(_ holding: PortfolioHolding) -> some View {
        HStack(spacing: 10) {
            // Checkbox
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    if selected.contains(holding.symbol) { selected.remove(holding.symbol) }
                    else { selected.insert(holding.symbol) }
                }
            } label: {
                Image(systemName: selected.contains(holding.symbol) ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected.contains(holding.symbol) ? DS.Color.accent : DS.Color.textTertiary)
                    .font(.system(size: 18))
            }

            // Main card — navigate to sell analysis on tap
            NavigationLink(destination: StockDetailView(symbol: holding.symbol, action: "sell")) {
                HStack(spacing: 12) {
                    // Company logo with sell dot overlay
                    ZStack(alignment: .bottomTrailing) {
                        TickerLogo(symbol: holding.symbol, size: 40)
                        if holding.sellResult?.passed == true {
                            Circle()
                                .fill(DS.Color.loss)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(DS.Color.background, lineWidth: 1.5))
                                .offset(x: 2, y: 2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(holding.symbol).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(DS.Color.textPrimary)
                            if holding.sellResult?.passed == true { DSBadge("SELL", color: DS.Color.loss) }
                            if holding.notes.hasPrefix("Synced from") { DSBadge("SYNCED", color: .purple) }
                        }
                        Text("\(holding.shares.formatted()) shares · avg \(ValueFormatting.currency(holding.buyPrice))")
                            .font(.caption).foregroundStyle(DS.Color.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(ValueFormatting.currency(holding.totalValue))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DS.Color.textPrimary)
                        Text(ValueFormatting.percent(holding.gainPercent)).font(.caption.bold())
                            .foregroundStyle((holding.gainPercent ?? 0) >= 0 ? DS.Color.gain : DS.Color.loss)
                    }

                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(DS.Color.textTertiary)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.large))
                .background(
                    holding.sellResult?.passed == true ? DS.Color.loss.opacity(0.06) : DS.Color.glassFill,
                    in: RoundedRectangle(cornerRadius: DS.Radius.large)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.large)
                        .stroke(holding.sellResult?.passed == true ? DS.Color.loss.opacity(0.22) : DS.Color.border)
                )
            }
            .buttonStyle(.plain)

            // Sell button — only visible when this holding is selected
            if selected.contains(holding.symbol) {
                Button {
                    sellTarget = holding
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(DS.Color.warning)
                        Text("Sell")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(DS.Color.warning)
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .contextMenu {
            Button("Record Sale") { sellTarget = holding }
            Button("Delete", role: .destructive) { Task { await model.remove(holding.symbol) } }
        }
    }

    // MARK: Sold history
    private var soldHistorySection: some View {
        VStack(spacing: 10) {
            HStack {
                DSSectionHeader(title: "TRADE HISTORY")
                Spacer()
                if model.totalRealized != 0 {
                    Text((model.totalRealized >= 0 ? "+" : "") + ValueFormatting.currency(model.totalRealized) + " realized")
                        .font(.caption.bold()).foregroundStyle(model.totalRealized >= 0 ? DS.Color.gain : DS.Color.loss)
                }
            }
            ForEach(model.soldPositions, id: \.stableID) { pos in
                HStack(spacing: 12) {
                    // Logo with a small checkmark overlay indicating completed sale
                    ZStack(alignment: .bottomTrailing) {
                        TickerLogo(symbol: pos.symbol, size: 38)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Color.background)
                            .background(
                                (pos.realizedGain ?? 0) >= 0 ? DS.Color.gain : DS.Color.loss,
                                in: Circle()
                            )
                            .offset(x: 2, y: 2)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(pos.symbol).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(DS.Color.textPrimary)
                        Text("Sold \(pos.sellDate) · \(pos.shares.formatted()) sh @ \(ValueFormatting.currency(pos.sellPrice))")
                            .font(.caption2).foregroundStyle(DS.Color.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        if let gain = pos.realizedGain {
                            Text((gain >= 0 ? "+" : "") + ValueFormatting.currency(gain))
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(gain >= 0 ? DS.Color.gain : DS.Color.loss)
                        }
                        if let pct = pos.realizedPct {
                            Text((pct >= 0 ? "+" : "") + String(format: "%.2f", pct) + "%")
                                .font(.caption2.monospaced()).foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                .background(DS.Color.glassFill, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.medium).stroke(DS.Color.border))
            }
        }
    }
}

// MARK: - Sell Holding Sheet
private struct SellHoldingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let holding: PortfolioHolding
    let onSell: (Double, String) async throws -> Void

    @State private var sellPriceText: String
    @State private var sellDate = Date()
    @State private var isSelling = false
    @State private var error: String?

    init(holding: PortfolioHolding, onSell: @escaping (Double, String) async throws -> Void) {
        self.holding = holding
        self.onSell  = onSell
        _sellPriceText = State(initialValue: holding.currentPrice.map { String(format: "%.2f", $0) } ?? "")
    }

    private var sellPrice: Double? { Double(sellPriceText) }
    private var proceeds: Double? { sellPrice.map { $0 * holding.shares } }
    private var gain: Double? {
        guard let sp = sellPrice, let bp = holding.buyPrice else { return nil }
        return (sp - bp) * holding.shares
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Header info
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Record Sale — \(holding.symbol)").font(.title3.bold()).foregroundStyle(DS.Color.textPrimary)
                            Text("\(holding.shares.formatted()) shares · bought @ \(ValueFormatting.currency(holding.buyPrice))")
                                .font(.subheadline).foregroundStyle(DS.Color.textSecondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)

                        // Sell price input
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
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.medium).stroke(DS.Color.accent.opacity(0.3)))
                        }

                        DatePicker("Sell Date", selection: $sellDate, displayedComponents: .date)
                            .foregroundStyle(DS.Color.textPrimary)

                        // Estimated P&L
                        if let pr = proceeds, let g = gain {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Proceeds").font(.caption).foregroundStyle(DS.Color.textSecondary)
                                    Text(ValueFormatting.currency(pr)).font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundStyle(DS.Color.textPrimary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                                .overlay(RoundedRectangle(cornerRadius: DS.Radius.medium).stroke(DS.Color.border))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Realized P&L").font(.caption).foregroundStyle(DS.Color.textSecondary)
                                    Text((g >= 0 ? "+" : "") + ValueFormatting.currency(g))
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundStyle(g >= 0 ? DS.Color.gain : DS.Color.loss)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                                .overlay(RoundedRectangle(cornerRadius: DS.Radius.medium).stroke(DS.Color.border))
                            }
                        }

                        if let error { Text(error).font(.caption).foregroundStyle(DS.Color.loss)
                            .frame(maxWidth: .infinity, alignment: .leading) }

                        // Confirm button
                        Button {
                            guard let price = sellPrice, !isSelling else { return }
                            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                            let dateStr = fmt.string(from: sellDate)
                            isSelling = true  // disable immediately — prevents double-tap 404
                            Task {
                                do {
                                    try await onSell(price, dateStr)
                                    dismiss()
                                } catch {
                                    let msg = error.localizedDescription
                                    // Treat 404, "not found", and decode errors as success
                                    // — the sale went through but the response couldn't be parsed
                                    if msg.contains("404") || msg.lowercased().contains("not found")
                                        || msg.lowercased().contains("missing")
                                        || msg.lowercased().contains("decod") {
                                        dismiss()
                                    } else {
                                        self.error = msg
                                        isSelling = false
                                    }
                                }
                            }
                        } label: {
                            HStack { Spacer()
                                if isSelling { ProgressView().tint(DS.Color.background).controlSize(.small) }
                                else { Text("Confirm Sale").font(.system(size: 16, weight: .semibold)).foregroundStyle(DS.Color.background) }
                                Spacer()
                            }.frame(height: 50)
                            .background(sellPrice != nil ? DS.Color.warning : DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                        }.disabled(sellPrice == nil || isSelling)
                    }.padding(20)
                }
            }
            .navigationTitle("Record Sale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Add Holding Sheet
private struct AddHoldingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var symbol = ""; @State private var suggestions: [StockSearchResult] = []
    @State private var date = Date(); @State private var price = ""; @State private var shares = "1"
    @State private var error: String?
    let onSave: (String, Date, Double?, Double) async throws -> Void

    var body: some View {
        NavigationStack {
            ZStack { DS.Color.background.ignoresSafeArea()
                Form {
                    Section("Stock") {
                        TextField("Search symbol (e.g. AAPL)", text: $symbol).textInputAutocapitalization(.characters)
                        ForEach(suggestions) { item in
                            Button { symbol = item.symbol; suggestions = [] } label: {
                                HStack { Text(item.symbol).font(.body.monospaced()); Spacer(); Text(item.sector ?? "").foregroundStyle(.secondary) }
                            }
                        }
                    }
                    DatePicker("Purchase date", selection: $date, displayedComponents: .date)
                    TextField("Purchase price (optional)", text: $price).keyboardType(.decimalPad)
                    TextField("Shares", text: $shares).keyboardType(.decimalPad)
                    if let error { Text(error).foregroundStyle(.red) }
                }.scrollContentBackground(.hidden)
            }
            .task(id: symbol) {
                try? await Task.sleep(for: .milliseconds(250))
                if !symbol.isEmpty { suggestions = (try? await APIClient.shared.search(symbol)) ?? [] }
            }
            .navigationTitle("Add Position")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            do { try await onSave(symbol, date, Double(price), Double(shares) ?? 1); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }
                    }.disabled(symbol.isEmpty)
                }
            }
        }
    }
}
