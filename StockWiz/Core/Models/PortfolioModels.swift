import Foundation

struct PortfolioHolding: Codable, Identifiable, Sendable {
    var id: String { symbol }
    let symbol: String
    let buyDate: String
    let buyPrice: Double?
    let shares: Double
    let notes: String
    let currentPrice: Double?
    let gainPercent: Double?
    let gainAbsolute: Double?
    let totalValue: Double?
    let sellResult: CriteriaResult?
    let metrics: StockMetrics?
    let history: [PortfolioPoint]

    enum CodingKeys: String, CodingKey {
        case symbol, shares, notes, metrics, history
        case buyDate = "buy_date"
        case buyPrice = "buy_price"
        case currentPrice = "current_price"
        case gainPercent = "gain_pct"
        case gainAbsolute = "gain_abs"
        case totalValue = "total_value"
        case sellResult = "sell_result"
    }
}

struct PortfolioPoint: Codable, Sendable {
    let date: String
    let close: Double
}

struct AddHoldingBody: Encodable, Sendable {
    let symbol: String
    let buyDate: String
    let buyPrice: Double?
    let shares: Double
    let notes: String
    enum CodingKeys: String, CodingKey {
        case symbol, shares, notes
        case buyDate = "buy_date"
        case buyPrice = "buy_price"
    }
}

struct SellHoldingBody: Encodable, Sendable {
    let sellPrice: Double
    let sellDate: String?
    enum CodingKeys: String, CodingKey {
        case sellPrice = "sell_price"
        case sellDate  = "sell_date"
    }
}

struct SoldPosition: Codable, Sendable, Identifiable {
    let id: String?          // optional — server may not return id on first insert
    let symbol: String
    let sellDate: String
    let sellPrice: Double
    let shares: Double
    let buyPrice: Double?
    let buyDate: String?
    let realizedGain: Double?
    let realizedPct: Double?
    let createdAt: String?

    // Stable identity for SwiftUI lists
    var stableID: String { id ?? "\(symbol)-\(sellDate)-\(sellPrice)" }

    enum CodingKeys: String, CodingKey {
        case id, symbol, shares
        case sellDate    = "sell_date"
        case sellPrice   = "sell_price"
        case buyDate     = "buy_date"
        case buyPrice    = "buy_price"
        case realizedGain = "realized_gain"
        case realizedPct  = "realized_pct"
        case createdAt   = "created_at"
    }
}

