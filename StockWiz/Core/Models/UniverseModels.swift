import Foundation

struct UniverseFilters: Codable, Sendable {
    let sector: String?
    let maxForwardPE: Double?
    let maxTrailingPE: Double?
    let minRevenueGrowth: Double?
    let minProfitMargin: Double?
    let minEarningsGrowth: Double?
    let near52WeekLowPercent: Double?
    let minMarketCap: Double?
    let limit: Int?
    let orderBy: String?
    let intentSummary: String?

    enum CodingKeys: String, CodingKey {
        case sector, limit
        case maxForwardPE = "max_forward_pe"
        case maxTrailingPE = "max_trailing_pe"
        case minRevenueGrowth = "min_revenue_growth"
        case minProfitMargin = "min_profit_margin"
        case minEarningsGrowth = "min_earnings_growth"
        case near52WeekLowPercent = "near_52w_low_pct"
        case minMarketCap = "min_market_cap"
        case orderBy = "order_by"
        case intentSummary = "intent_summary"
    }

    var labels: [String] {
        var values: [String] = []
        if let sector { values.append(sector) }
        if let maxForwardPE { values.append("Fwd P/E ≤ \(maxForwardPE.formatted())") }
        if let maxTrailingPE { values.append("P/E ≤ \(maxTrailingPE.formatted())") }
        if let minRevenueGrowth { values.append("Revenue ≥ \(ValueFormatting.percent(minRevenueGrowth))") }
        if let minProfitMargin { values.append("Margin ≥ \(ValueFormatting.percent(minProfitMargin))") }
        if let near52WeekLowPercent { values.append("Within \(ValueFormatting.percent(near52WeekLowPercent)) of low") }
        if let minMarketCap { values.append("Cap ≥ \(ValueFormatting.compact(minMarketCap))") }
        return values
    }
}

struct UniverseStock: Codable, Identifiable, Hashable, Sendable {
    var id: String { symbol }
    let symbol: String
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

    enum CodingKeys: String, CodingKey {
        case symbol, sector, industry
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
    }
}

struct AgentResultEvent: Codable, Sendable {
    let type: String
    let filters: UniverseFilters
    let results: [UniverseStock]
    let totalMatched: Int

    enum CodingKeys: String, CodingKey {
        case type, filters, results
        case totalMatched = "total_matched"
    }
}

struct ScreenerSignal: Codable, Identifiable, Sendable {
    var id: String { symbol }
    let symbol: String
    let classification: String
    let metrics: UniverseStock
    let buyResult: CriteriaResult
    let watchResult: CriteriaResult

    enum CodingKeys: String, CodingKey {
        case symbol, classification, metrics
        case buyResult = "buy_result"
        case watchResult = "watch_result"
    }
}

struct StreamToken: Codable, Sendable {
    let token: String
}

struct ChatMessage: Codable, Identifiable, Sendable {
    let id: UUID
    let role: String
    var content: String

    init(id: UUID = UUID(), role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }

    enum CodingKeys: String, CodingKey { case role, content }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        role = try values.decode(String.self, forKey: .role)
        content = try values.decode(String.self, forKey: .content)
    }
}
