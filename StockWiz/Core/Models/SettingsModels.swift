import Foundation

struct InvestmentProfile: Codable, Sendable {
    var riskTolerance: String
    var preferredSectors: [String]
    var holdDuration: String
    var maxPositionUSD: Double
    var taxSensitive: Bool
    var notes: String
    enum CodingKeys: String, CodingKey {
        case notes
        case riskTolerance = "risk_tolerance"
        case preferredSectors = "preferred_sectors"
        case holdDuration = "hold_duration"
        case maxPositionUSD = "max_position_usd"
        case taxSensitive = "tax_sensitive"
    }
}

extension InvestmentProfile {
    static let defaults = InvestmentProfile(riskTolerance: "moderate", preferredSectors: [], holdDuration: "medium", maxPositionUSD: 5_000, taxSensitive: false, notes: "")
}

struct UserAlert: Codable, Identifiable, Sendable {
    let id: String
    let symbol: String
    let alertType: String
    let threshold: Double?
    var enabled: Bool
    enum CodingKeys: String, CodingKey { case id, symbol, threshold, enabled; case alertType = "alert_type" }
}

struct BrokerageStatus: Codable, Sendable { let connected: Bool; let connections: [BrokerageConnection]; let error: String? }
struct BrokerageConnection: Codable, Identifiable, Sendable { let id: String; let institution: String; let updatedAt: String?; enum CodingKeys: String, CodingKey { case id, institution; case updatedAt = "updated_at" } }
struct PlaidLinkToken: Codable, Sendable { let linkToken: String; enum CodingKeys: String, CodingKey { case linkToken = "link_token" } }
struct PlaidExchangeResult: Codable, Sendable { let connected: Bool; let institution: String }

enum CriterionValue: Codable, Sendable {
    case number(Double), text(String)
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let number = try? value.decode(Double.self) { self = .number(number) }
        else { self = .text(try value.decode(String.self)) }
    }
    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self { case .number(let number): try value.encode(number); case .text(let text): try value.encode(text) }
    }
    var display: String { get { switch self { case .number(let value): return value.formatted(); case .text(let value): return value } } set { switch self { case .number: self = .number(Double(newValue) ?? 0); case .text: self = .text(newValue) } } }
}

struct CriteriaSettingRule: Codable, Identifiable, Sendable {
    var id: String; var description: String; var field: String; var `operator`: String; var value: CriterionValue
}
struct CriteriaMode: Codable, Sendable {
    var description: String; var rules: [CriteriaSettingRule]; var minRulesMet: Int
    enum CodingKeys: String, CodingKey { case description, rules; case minRulesMet = "min_rules_met" }
}
struct CriteriaConfiguration: Codable, Sendable { var buy: CriteriaMode; var watch: CriteriaMode; var sell: CriteriaMode }
