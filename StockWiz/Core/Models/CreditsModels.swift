import Foundation

struct CreditsStatus: Codable, Sendable {
    let hasOwnKey: Bool
    let unlimited: Bool
    let metered: Bool
    let tokensUsed: Int
    let tokenLimit: Int
    let remaining: Int
    let pctUsed: Double
    let warning: Bool
    let exhausted: Bool
    let period: String

    enum CodingKeys: String, CodingKey {
        case unlimited, metered, warning, exhausted, period
        case hasOwnKey = "has_own_key"
        case tokensUsed = "tokens_used"
        case tokenLimit = "token_limit"
        case remaining
        case pctUsed = "pct_used"
    }
}

/// Body shape returned by the backend on non-2xx AI responses, e.g.
/// `{"detail": "friendly message", "code": "credits_exhausted"}`.
struct APIErrorBody: Decodable {
    let detail: String?
    let code: String?
}
