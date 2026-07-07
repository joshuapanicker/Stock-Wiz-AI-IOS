import Foundation

struct MarketContext: Codable, Sendable {
    let marketTrend: String
    let vix: Double?
    let spyLatest: Double?
    let spy20DMA: Double?
    let spy50DMA: Double?

    enum CodingKeys: String, CodingKey {
        case marketTrend = "market_trend"
        case vix
        case spyLatest = "spy_latest"
        case spy20DMA = "spy_20dma"
        case spy50DMA = "spy_50dma"
    }
}

/// Last-known prices captured from search results and lists, so a freshly
/// opened detail screen can show a price immediately instead of waiting on
/// the network.
@MainActor
enum QuoteSeed {
    private(set) static var prices: [String: Double] = [:]

    static func seed(symbol: String, price: Double?) {
        guard let price else { return }
        prices[symbol.uppercased()] = price
    }

    static func price(for symbol: String) -> Double? {
        prices[symbol.uppercased()]
    }
}

struct StockSearchResult: Codable, Identifiable, Hashable, Sendable {
    var id: String { symbol }
    let symbol: String
    let sector: String?
    let closePrice: Double?
    let marketCap: Double?

    enum CodingKeys: String, CodingKey {
        case symbol, sector
        case closePrice = "close_price"
        case marketCap = "market_cap"
    }
}

struct PriceBar: Codable, Identifiable, Sendable {
    var id: String { date }
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int

    var parsedDate: Date? { Self.dateFormatter.date(from: date) }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct StockMetrics: Codable, Sendable {
    let symbol: String
    let date: String
    let closePrice: Double?
    let low52Week: Double?
    let high52Week: Double?
    let trailingPE: Double?
    let forwardPE: Double?
    let profitMargin: Double?
    let operatingMargin: Double?
    let revenueGrowth: Double?
    let earningsGrowth: Double?
    let marketCap: Double?
    let sector: String?
    let industry: String?
    let distanceToLow: Double?
    let distanceToHigh: Double?
    let closerTo52WeekLow: Bool?

    enum CodingKeys: String, CodingKey {
        case symbol, date, sector, industry
        case closePrice = "close_price"
        case low52Week = "low_52_week"
        case high52Week = "high_52_week"
        case trailingPE = "trailing_pe"
        case forwardPE = "forward_pe"
        case profitMargin = "profit_margin"
        case operatingMargin = "operating_margin"
        case revenueGrowth = "revenue_growth"
        case earningsGrowth = "earnings_growth"
        case marketCap = "market_cap"
        case distanceToLow = "distance_to_low_pct"
        case distanceToHigh = "distance_to_high_pct"
        case closerTo52WeekLow = "closer_to_52w_low"
    }
}

struct CriteriaRule: Codable, Identifiable, Sendable {
    let id: String
    let description: String
    let passed: Bool
}

struct CriteriaResult: Codable, Sendable {
    let passed: Bool
    let rulesMet: Int
    let rulesTotal: Int
    let minRequired: Int
    let details: [CriteriaRule]

    enum CodingKeys: String, CodingKey {
        case passed, details
        case rulesMet = "rules_met"
        case rulesTotal = "rules_total"
        case minRequired = "min_required"
    }
}

struct AnalysisResult: Codable, Sendable {
    let symbol: String
    let action: String
    let metrics: StockMetrics
    let market: MarketContext
    let criteriaResult: CriteriaResult
    let analysisText: String

    enum CodingKeys: String, CodingKey {
        case symbol, action, metrics, market
        case criteriaResult = "criteria_result"
        case analysisText = "analysis_text"
    }
}

