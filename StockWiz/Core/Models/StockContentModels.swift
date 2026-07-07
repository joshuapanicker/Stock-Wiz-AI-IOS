import Foundation

struct StockNews: Codable, Sendable {
    let headlines: [Headline]
    let earnings: Earnings?
}

struct Headline: Codable, Identifiable, Sendable {
    var id: String { url.isEmpty ? title : url }
    let title: String
    let publisher: String
    let age: String
    let url: String
}

struct Earnings: Codable, Sendable {
    let quarter: String?
    let epsActual: Double?
    let epsEstimate: Double?
    let beatMiss: String?
    let surprisePercent: Double?

    enum CodingKeys: String, CodingKey {
        case quarter
        case epsActual = "eps_actual"
        case epsEstimate = "eps_estimate"
        case beatMiss = "beat_miss"
        case surprisePercent = "surprise_pct"
    }
}

struct Financials: Codable, Sendable {
    let quarters: [FinancialQuarter]
    let revenueGrowthYearOverYear: Double?
    let profitMargin: Double?

    enum CodingKeys: String, CodingKey {
        case quarters
        case revenueGrowthYearOverYear = "revenue_growth_yoy"
        case profitMargin = "profit_margin"
    }
}

struct FinancialQuarter: Codable, Identifiable, Sendable {
    var id: String { quarter }
    let quarter: String
    let revenue: Double?
    let netIncome: Double?

    enum CodingKeys: String, CodingKey {
        case quarter, revenue
        case netIncome = "net_income"
    }
}

