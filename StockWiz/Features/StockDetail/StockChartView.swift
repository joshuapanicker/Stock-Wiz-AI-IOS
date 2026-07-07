import Charts
import SwiftUI

enum StockChartType: String, CaseIterable, Identifiable {
    case candlestick, area, bollinger, movingAverages, macd, rsi, volumeProfile, roi, relativeStrength
    var id: Self { self }

    var label: String {
        switch self {
        case .candlestick: "Candlestick"
        case .area: "Area"
        case .bollinger: "Bollinger Bands"
        case .movingAverages: "Moving Averages"
        case .macd: "MACD"
        case .rsi: "RSI (14)"
        case .volumeProfile: "Volume Profile"
        case .roi: "ROI %"
        case .relativeStrength: "vs SPY"
        }
    }

    var description: String {
        switch self {
        case .candlestick: "OHLC price action"
        case .area: "Smoothed price line"
        case .bollinger: "20-day volatility bands"
        case .movingAverages: "20 / 50 / 200-day averages"
        case .macd: "Momentum and signal line"
        case .rsi: "Overbought and oversold momentum"
        case .volumeProfile: "Trading volume by price"
        case .roi: "Return from period start"
        case .relativeStrength: "Performance against SPY"
        }
    }
}

struct StockChartView: View {
    let type: StockChartType
    let history: [PriceBar]
    let benchmark: [PriceBar]
    @Binding var selectedDate: Date?

    var body: some View {
        Group {
            switch type {
            case .candlestick: candleChart
            case .area: areaChart
            case .bollinger: bollingerChart
            case .movingAverages: movingAverageChart
            case .macd: macdChart
            case .rsi: rsiChart
            case .volumeProfile: volumeProfileChart
            case .roi: roiChart
            case .relativeStrength: relativeStrengthChart
            }
        }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 245)
    }

    private var dated: [(bar: PriceBar, date: Date)] {
        history.compactMap { bar in bar.parsedDate.map { (bar, $0) } }
    }

    private var candleChart: some View {
        Chart(dated, id: \.bar.id) { item in
            BarMark(
                x: .value("Date", item.date),
                yStart: .value("Low", item.bar.low),
                yEnd: .value("High", item.bar.high),
                width: .fixed(1)
            )
            .foregroundStyle(item.bar.close >= item.bar.open ? Color.green : Color.red)
            RectangleMark(
                x: .value("Date", item.date),
                yStart: .value("Open", item.bar.open),
                yEnd: .value("Close", item.bar.close),
                width: .fixed(4)
            )
            .foregroundStyle(item.bar.close >= item.bar.open ? Color.green : Color.red)
        }
        .chartXSelection(value: $selectedDate)
    }

    private var areaChart: some View {
        Chart(dated, id: \.bar.id) { item in
            AreaMark(x: .value("Date", item.date), y: .value("Price", item.bar.close))
                .foregroundStyle(.linearGradient(colors: [.green.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Date", item.date), y: .value("Price", item.bar.close))
                .foregroundStyle(.green).interpolationMethod(.catmullRom)
        }
        .chartXSelection(value: $selectedDate)
    }

    private var movingAverageChart: some View {
        let points = IndicatorMath.movingAveragePoints(history)
        return Chart(points) { point in
            LineMark(x: .value("Date", point.date), y: .value("Value", point.value), series: .value("Series", point.series))
                .foregroundStyle(by: .value("Series", point.series))
        }
        .chartForegroundStyleScale(["Price": .green, "MA 20": .blue, "MA 50": .orange, "MA 200": .purple])
        .chartXSelection(value: $selectedDate)
    }

    private var bollingerChart: some View {
        let points = IndicatorMath.bollinger(history)
        return Chart(points) { point in
            LineMark(x: .value("Date", point.date), y: .value("Price", point.close)).foregroundStyle(.green)
            LineMark(x: .value("Date", point.date), y: .value("Upper", point.upper)).foregroundStyle(.blue.opacity(0.7))
            LineMark(x: .value("Date", point.date), y: .value("Middle", point.middle)).foregroundStyle(.secondary)
            LineMark(x: .value("Date", point.date), y: .value("Lower", point.lower)).foregroundStyle(.blue.opacity(0.7))
        }
        .chartXSelection(value: $selectedDate)
    }

    private var roiChart: some View {
        let points = IndicatorMath.roi(history)
        return Chart(points) { point in
            AreaMark(x: .value("Date", point.date), y: .value("Return", point.value))
                .foregroundStyle(point.value >= 0 ? Color.green.opacity(0.25) : Color.red.opacity(0.25))
            LineMark(x: .value("Date", point.date), y: .value("Return", point.value))
                .foregroundStyle(point.value >= 0 ? .green : .red)
            RuleMark(y: .value("Break even", 0)).foregroundStyle(.secondary.opacity(0.4))
        }
        .chartYScale(domain: .automatic(includesZero: true))
        .chartXSelection(value: $selectedDate)
    }

    private var rsiChart: some View {
        let points = IndicatorMath.rsi(history)
        return Chart(points) { point in
            LineMark(x: .value("Date", point.date), y: .value("RSI", point.value)).foregroundStyle(.purple)
            RuleMark(y: .value("Overbought", 70)).foregroundStyle(.red.opacity(0.6))
            RuleMark(y: .value("Oversold", 30)).foregroundStyle(.green.opacity(0.6))
        }
        .chartYScale(domain: 0...100)
        .chartXSelection(value: $selectedDate)
    }

    private var macdChart: some View {
        let points = IndicatorMath.macd(history)
        return Chart(points) { point in
            BarMark(x: .value("Date", point.date), y: .value("Histogram", point.histogram))
                .foregroundStyle(point.histogram >= 0 ? Color.green.opacity(0.5) : Color.red.opacity(0.5))
            LineMark(x: .value("Date", point.date), y: .value("MACD", point.macd), series: .value("Series", "MACD")).foregroundStyle(.blue)
            LineMark(x: .value("Date", point.date), y: .value("Signal", point.signal), series: .value("Series", "Signal")).foregroundStyle(.orange)
        }
        .chartXSelection(value: $selectedDate)
    }

    private var volumeProfileChart: some View {
        Chart(IndicatorMath.volumeProfile(history)) { bucket in
            BarMark(x: .value("Volume", bucket.volume), y: .value("Price", bucket.price))
                .foregroundStyle(.green.gradient)
        }
    }

    private var relativeStrengthChart: some View {
        let points = IndicatorMath.relativeStrength(history, benchmark: benchmark)
        return Chart(points) { point in
            LineMark(x: .value("Date", point.date), y: .value("Performance", point.value), series: .value("Series", point.series))
                .foregroundStyle(by: .value("Series", point.series))
        }
        .chartForegroundStyleScale(["Stock": .green, "SPY": .purple])
        .chartXSelection(value: $selectedDate)
    }
}

private enum IndicatorMath {
    struct SeriesPoint: Identifiable { let id = UUID(); let date: Date; let value: Double; let series: String }
    struct BandPoint: Identifiable { let id = UUID(); let date: Date; let close, upper, middle, lower: Double }
    struct MACDPoint: Identifiable { let id = UUID(); let date: Date; let macd, signal, histogram: Double }
    struct Bucket: Identifiable { let id = UUID(); let price: Double; let volume: Int }

    static func sma(_ values: [Double], period: Int, index: Int) -> Double? {
        guard index >= period - 1 else { return nil }
        return values[(index - period + 1)...index].reduce(0, +) / Double(period)
    }

    static func ema(_ values: [Double], period: Int) -> [Double] {
        guard let first = values.first else { return [] }
        let multiplier = 2.0 / Double(period + 1)
        return values.dropFirst().reduce(into: [first]) { output, value in
            output.append((value - output.last!) * multiplier + output.last!)
        }
    }

    static func movingAveragePoints(_ history: [PriceBar]) -> [SeriesPoint] {
        let values = history.map(\.close)
        var result: [SeriesPoint] = []
        for (index, bar) in history.enumerated() {
            guard let date = bar.parsedDate else { continue }
            result.append(.init(date: date, value: bar.close, series: "Price"))
            for (period, name) in [(20, "MA 20"), (50, "MA 50"), (200, "MA 200")] {
                if let value = sma(values, period: period, index: index) { result.append(.init(date: date, value: value, series: name)) }
            }
        }
        return result
    }

    static func bollinger(_ history: [PriceBar]) -> [BandPoint] {
        let values = history.map(\.close)
        return history.enumerated().compactMap { index, bar in
            guard let date = bar.parsedDate, let mean = sma(values, period: 20, index: index) else { return nil }
            let window = values[(index - 19)...index]
            let deviation = sqrt(window.reduce(0) { $0 + pow($1 - mean, 2) } / 20)
            return .init(date: date, close: bar.close, upper: mean + 2 * deviation, middle: mean, lower: mean - 2 * deviation)
        }
    }

    static func roi(_ history: [PriceBar]) -> [SeriesPoint] {
        guard let base = history.first?.close, base != 0 else { return [] }
        return history.compactMap { bar in bar.parsedDate.map { .init(date: $0, value: (bar.close / base - 1) * 100, series: "ROI") } }
    }

    static func rsi(_ history: [PriceBar]) -> [SeriesPoint] {
        guard history.count > 14 else { return [] }
        let changes = zip(history.dropFirst(), history).map { $0.close - $1.close }
        return history.enumerated().compactMap { index, bar in
            guard index >= 14, let date = bar.parsedDate else { return nil }
            let window = changes[(index - 14)..<index]
            let gains = window.reduce(0) { $0 + max($1, 0) } / 14
            let losses = window.reduce(0) { $0 + max(-$1, 0) } / 14
            let value = losses == 0 ? 100 : 100 - 100 / (1 + gains / losses)
            return .init(date: date, value: value, series: "RSI")
        }
    }

    static func macd(_ history: [PriceBar]) -> [MACDPoint] {
        let values = history.map(\.close), fast = ema(values, period: 12), slow = ema(values, period: 26)
        let line = zip(fast, slow).map(-)
        let signal = ema(line, period: 9)
        return history.indices.compactMap { index in
            guard let date = history[index].parsedDate else { return nil }
            return .init(date: date, macd: line[index], signal: signal[index], histogram: line[index] - signal[index])
        }
    }

    static func volumeProfile(_ history: [PriceBar]) -> [Bucket] {
        guard let low = history.map(\.low).min(), let high = history.map(\.high).max(), high > low else { return [] }
        let size = (high - low) / 20
        var volumes = Array(repeating: 0, count: 20)
        for bar in history { volumes[min(19, max(0, Int((bar.close - low) / size)))] += bar.volume }
        return volumes.indices.map { .init(price: low + (Double($0) + 0.5) * size, volume: volumes[$0]) }
    }

    static func relativeStrength(_ history: [PriceBar], benchmark: [PriceBar]) -> [SeriesPoint] {
        guard let stockBase = history.first?.close, let spyBase = benchmark.first?.close else { return [] }
        var result = history.compactMap { bar in bar.parsedDate.map { SeriesPoint(date: $0, value: (bar.close / stockBase - 1) * 100, series: "Stock") } }
        result += benchmark.compactMap { bar in bar.parsedDate.map { SeriesPoint(date: $0, value: (bar.close / spyBase - 1) * 100, series: "SPY") } }
        return result
    }
}

