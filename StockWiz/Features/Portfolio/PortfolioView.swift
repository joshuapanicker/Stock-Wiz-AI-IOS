import Charts
import Observation
import SwiftUI

@MainActor @Observable
private final class PortfolioModel {
    var holdings: [PortfolioHolding] = []
    var isLoading = true
    var error: String?

    var totalValue: Double { holdings.compactMap(\.totalValue).reduce(0, +) }
    var netGain: Double { holdings.compactMap(\.gainAbsolute).reduce(0, +) }
    var sellSignals: Int { holdings.filter { $0.sellResult?.passed == true }.count }

    init() {
        if let data = UserDefaults.standard.data(forKey: "cachedPortfolio"),
           let cached = try? JSONDecoder().decode([PortfolioHolding].self, from: data) {
            holdings = cached
            isLoading = false
        }
    }

    func load() async {
        isLoading = holdings.isEmpty; error = nil
        do {
            holdings = try await APIClient.shared.portfolio()
            if let data = try? JSONEncoder().encode(holdings) { UserDefaults.standard.set(data, forKey: "cachedPortfolio") }
        }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }

    func add(symbol: String, date: Date, price: Double?, shares: Double) async throws {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        try await APIClient.shared.addHolding(.init(symbol: symbol.uppercased(), buyDate: formatter.string(from: date), buyPrice: price, shares: shares, notes: ""))
        await load()
    }

    func remove(_ symbol: String) async {
        holdings.removeAll { $0.symbol == symbol }
        try? await APIClient.shared.deleteHolding(symbol: symbol)
        await load()
    }
}

struct PortfolioView: View {
    @State private var model = PortfolioModel()
    @State private var showingAdd = false
    @State private var showingBrokerage = false
    @State private var selected = Set<String>()

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.holdings.isEmpty { portfolioLoading }
                else if let error = model.error, model.holdings.isEmpty {
                    ContentUnavailableView("Portfolio unavailable", systemImage: "wifi.exclamationmark", description: Text(error))
                } else if model.holdings.isEmpty {
                    ContentUnavailableView("No positions", systemImage: "briefcase", description: Text("Add a stock or connect a brokerage in Settings."))
                } else { portfolioContent }
            }
            .navigationTitle("Portfolio")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingBrokerage = true } label: { Image(systemName: "building.columns") }
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) { AddHoldingView { symbol, date, price, shares in try await model.add(symbol: symbol, date: date, price: price, shares: shares) } }
            .sheet(isPresented: $showingBrokerage) { BrokerageSettingsView() }
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }

    private var portfolioContent: some View {
        ZStack(alignment: .top) {
            portfolioBackground
            ScrollView {
            VStack(spacing: 16) {
                portfolioHero
                performanceChart
                allocationChart
                HStack { stat("arrow.up.right", "Net P&L", ValueFormatting.currency(model.netGain), model.netGain >= 0 ? .green : .red); stat("exclamationmark.triangle", "Sell signals", "\(model.sellSignals)", .orange) }
                selectionBar
                HStack { Text("POSITIONS").font(.caption.bold()).tracking(1.3).foregroundStyle(.secondary); Spacer(); Text("\(model.holdings.count) HOLDINGS").font(.caption2.monospaced()).foregroundStyle(.tertiary) }
                ForEach(model.holdings) { holding in holdingRow(holding) }
            }.padding()
            }
        }
    }

    private var portfolioBackground: some View { ZStack(alignment: .top) { Color(red: 0.025, green: 0.03, blue: 0.037).ignoresSafeArea(); RadialGradient(colors: [Color.green.opacity(0.12), .clear], center: UnitPoint(x: 0.12, y: 0), startRadius: 5, endRadius: 360).frame(height: 520).ignoresSafeArea(); RadialGradient(colors: [Color.cyan.opacity(0.055), .clear], center: UnitPoint(x: 0.95, y: 0.3), startRadius: 5, endRadius: 280).frame(height: 650).ignoresSafeArea() } }

    private var portfolioHero: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack { Label("PORTFOLIO COMMAND CENTER", systemImage: "waveform.path.ecg").font(.caption2.bold()).tracking(1.2).foregroundStyle(.green); Spacer(); HStack(spacing: 5) { Circle().fill(.green).frame(width: 5, height: 5); Text("LIVE").font(.system(size: 9, weight: .bold)).foregroundStyle(.green) } }
            Text("Total market value").font(.caption).foregroundStyle(.secondary)
            Text(ValueFormatting.currency(model.totalValue)).font(.system(size: 36, weight: .bold, design: .monospaced)).minimumScaleFactor(0.7)
            HStack { Label("\(model.holdings.count) active positions", systemImage: "square.stack.3d.up"); Spacer(); Text(model.netGain >= 0 ? "+\(ValueFormatting.currency(model.netGain))" : ValueFormatting.currency(model.netGain)).foregroundStyle(model.netGain >= 0 ? .green : .red).fontWeight(.semibold) }.font(.caption)
        }.padding(20).background(LinearGradient(colors: [Color.green.opacity(0.12), Color.white.opacity(0.035)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 23)).overlay(RoundedRectangle(cornerRadius: 23).stroke(LinearGradient(colors: [Color.green.opacity(0.32), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))).shadow(color: .green.opacity(0.07), radius: 20, y: 10)
    }

    private var portfolioLoading: some View { ZStack { portfolioBackground; VStack(alignment: .leading, spacing: 14) { Text("Preparing your command center").font(.title3.bold()); Text("Syncing positions, market values, and sell signals…").font(.caption).foregroundStyle(.secondary); ProgressView().tint(.green); ForEach(0..<3) { _ in RoundedRectangle(cornerRadius: 17).fill(Color.white.opacity(0.05)).frame(height: 84).redacted(reason: .placeholder) } }.padding() } }

    private var performanceChart: some View {
        let points = combinedHistory
        return VStack(alignment: .leading, spacing: 8) {
            HStack { VStack(alignment: .leading, spacing: 3) { Text("VALUE TRAJECTORY").font(.caption.bold()).tracking(1); Text("Combined market value over time").font(.caption2).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(.green) }
            Chart(points, id: \.0) { point in
                AreaMark(x: .value("Date", point.0), y: .value("Value", point.1)).foregroundStyle(LinearGradient(colors: [.green.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", point.0), y: .value("Value", point.1)).foregroundStyle(.green).lineStyle(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { AxisValueLabel().foregroundStyle(.secondary) } }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 5])).foregroundStyle(Color.white.opacity(0.08)); AxisValueLabel { if let amount = value.as(Double.self) { Text(compactCurrency(amount)) } }.foregroundStyle(.secondary) } }
            .chartPlotStyle { plot in plot.background(Color.black.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10)) }
            .frame(height: 190)
        }.padding().background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 19)).overlay(RoundedRectangle(cornerRadius: 19).stroke(Color.white.opacity(0.07)))
    }

    private var combinedHistory: [(String, Double)] {
        var totals: [String: Double] = [:]
        for holding in model.holdings { for point in holding.history { totals[point.date, default: 0] += point.close * holding.shares } }
        return totals.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private func compactCurrency(_ value: Double) -> String { if abs(value) >= 1_000_000 { return "$\((value / 1_000_000).formatted(.number.precision(.fractionLength(1))))M" }; if abs(value) >= 1_000 { return "$\((value / 1_000).formatted(.number.precision(.fractionLength(0))))K" }; return "$\(value.formatted(.number.precision(.fractionLength(0))))" }

    private var allocationChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { VStack(alignment: .leading) { Text("ALLOCATION MAP").font(.caption.bold()).tracking(1); Text("Position concentration by market value").font(.caption2).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chart.pie.fill").foregroundStyle(.cyan) }
            Chart(model.holdings) { holding in
                SectorMark(angle: .value("Value", holding.totalValue ?? 0), innerRadius: .ratio(0.62), angularInset: 2)
                    .foregroundStyle(by: .value("Symbol", holding.symbol))
            }.frame(height: 170).chartLegend(position: .bottom, spacing: 12)
        }.padding().background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 19)).overlay(RoundedRectangle(cornerRadius: 19).stroke(Color.white.opacity(0.07)))
    }

    private var selectionBar: some View {
        HStack {
            Button(selected.count == model.holdings.count ? "Clear All" : "Select All") {
                selected = selected.count == model.holdings.count ? [] : Set(model.holdings.map(\.symbol))
            }
            Spacer()
            if !selected.isEmpty {
                Text("\(selected.count) selected").font(.caption).foregroundStyle(.secondary)
                Button("Delete", role: .destructive) {
                    let symbols = selected; selected = []
                    Task { for symbol in symbols { await model.remove(symbol) } }
                }
            }
        }.font(.subheadline).padding(.horizontal, 4)
    }

    private func stat(_ icon: String, _ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) { Image(systemName: icon).foregroundStyle(color); Text(label).font(.caption).foregroundStyle(.secondary); Text(value).font(.headline.monospaced()) }
            .frame(maxWidth: .infinity, alignment: .leading).padding().background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07)))
    }

    private func holdingRow(_ holding: PortfolioHolding) -> some View {
        HStack(spacing: 10) {
            Button { if selected.contains(holding.symbol) { selected.remove(holding.symbol) } else { selected.insert(holding.symbol) } } label: {
                Image(systemName: selected.contains(holding.symbol) ? "checkmark.square.fill" : "square").foregroundStyle(selected.contains(holding.symbol) ? .green : .secondary)
            }
            NavigationLink(destination: StockDetailView(symbol: holding.symbol, action: "sell")) {
            HStack {
                VStack(alignment: .leading) {
                    HStack { Text(holding.symbol).font(.headline.monospaced()); if holding.sellResult?.passed == true { Text("SELL").font(.caption2.bold()).foregroundStyle(.red) } }
                    Text("\(holding.shares.formatted()) shares · avg \(ValueFormatting.currency(holding.buyPrice))").font(.caption).foregroundStyle(.secondary)
                    if holding.notes.hasPrefix("Synced from") { Text(holding.notes).font(.caption2).foregroundStyle(.purple) }
                }
                Spacer()
                VStack(alignment: .trailing) { Text(ValueFormatting.currency(holding.totalValue)).font(.headline.monospaced()); Text(ValueFormatting.percent(holding.gainPercent)).foregroundStyle((holding.gainPercent ?? 0) >= 0 ? .green : .red).font(.caption) }
            }.padding().background(LinearGradient(colors: [Color.white.opacity(0.055), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(holding.sellResult?.passed == true ? Color.red.opacity(0.2) : Color.white.opacity(0.07)))
            }.buttonStyle(.plain)
        }.contextMenu { Button("Delete", role: .destructive) { Task { await model.remove(holding.symbol) } } }
    }
}

private struct AddHoldingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var symbol = ""; @State private var suggestions: [StockSearchResult] = []; @State private var date = Date(); @State private var price = ""; @State private var shares = "1"; @State private var error: String?
    let onSave: (String, Date, Double?, Double) async throws -> Void
    var body: some View {
        NavigationStack { Form { Section("Stock") { TextField("Search symbol", text: $symbol).textInputAutocapitalization(.characters); ForEach(suggestions) { item in Button { symbol = item.symbol; suggestions = [] } label: { HStack { Text(item.symbol).font(.body.monospaced()); Spacer(); Text(item.sector ?? "").foregroundStyle(.secondary) } } } }; DatePicker("Purchase date", selection: $date, displayedComponents: .date); TextField("Purchase price (optional)", text: $price).keyboardType(.decimalPad); TextField("Shares", text: $shares).keyboardType(.decimalPad); if let error { Text(error).foregroundStyle(.red) } }
            .task(id: symbol) { try? await Task.sleep(for: .milliseconds(250)); if !symbol.isEmpty { suggestions = (try? await APIClient.shared.search(symbol)) ?? [] } }
            .navigationTitle("Add Position").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { do { try await onSave(symbol, date, Double(price), Double(shares) ?? 1); dismiss() } catch { self.error = error.localizedDescription } } }.disabled(symbol.isEmpty) } } }
    }
}
