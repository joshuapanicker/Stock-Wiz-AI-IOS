import Foundation
import Supabase

actor APIClient {
    static let shared = APIClient()

    enum ClientError: LocalizedError {
        case notConfigured
        case offline
        case invalidResponse
        case decoding(String)
        case server(status: Int, message: String)
        case creditsExhausted(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: "The API URL has not been configured."
            case .offline: "You appear to be offline. Check your connection and try again."
            case .invalidResponse: "The server returned an invalid response."
            case let .decoding(message): "StockWiz received unexpected data: \(message)"
            case let .server(status, message): "Server error \(status): \(message)"
            case let .creditsExhausted(message): message
            }
        }
    }

    /// Decode a non-2xx response body into the right ClientError case.
    /// Falls back to the raw body text if it isn't the expected `{"detail","code"}` shape.
    nonisolated private func mapError(status: Int, data: Data) -> ClientError {
        if let body = try? JSONDecoder().decode(APIErrorBody.self, from: data) {
            if body.code == "credits_exhausted" {
                return .creditsExhausted(body.detail ?? "You've used all your free AI credits for this month.")
            }
            if let detail = body.detail {
                return .server(status: status, message: detail)
            }
        }
        return .server(status: status, message: String(data: data, encoding: .utf8) ?? "Unknown error")
    }

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func get<T: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = [],
        as type: T.Type = T.self
    ) async throws -> T {
        let data = try await request(path: path, queryItems: queryItems, method: "GET")
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw ClientError.decoding(error.localizedDescription)
        }
    }

    func checkMarketConnection() async throws {
        _ = try await request(path: "/api/market", method: "GET")
    }

    private func request(
        path: String,
        queryItems: [URLQueryItem] = [],
        method: String,
        body: Data? = nil
    ) async throws -> Data {
        guard let baseURL = AppConfiguration.shared.apiBaseURL else {
            throw ClientError.notConfigured
        }
        var cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        if baseURL.path.hasSuffix("/api"), cleanPath.hasPrefix("api/") {
            cleanPath.removeFirst(4)
        }
        let endpoint = baseURL.appending(path: cleanPath)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw ClientError.invalidResponse
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw ClientError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if let session = try? await SupabaseProvider.client.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw ClientError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            throw mapError(status: http.statusCode, data: data)
        }
        return data
    }

    func send<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        body: Body,
        as type: Response.Type = Response.self
    ) async throws -> Response {
        let data = try await request(path: path, method: method, body: encoder.encode(body))
        return try decoder.decode(type, from: data)
    }

    func delete(_ path: String, queryItems: [URLQueryItem] = []) async throws {
        _ = try await request(path: path, queryItems: queryItems, method: "DELETE")
    }

    func streamAgent(query: String) async throws -> AsyncThrowingStream<String, Error> {
        struct Body: Encodable { let query: String; let messages: [ChatMessage] }
        return try await eventStream(path: "/api/universe/agent", body: Body(query: query, messages: []))
    }

    func streamStockChat(symbol: String, messages: [ChatMessage]) async throws -> AsyncThrowingStream<String, Error> {
        struct Body: Encodable { let messages: [ChatMessage] }
        return try await eventStream(path: "/api/chat/\(symbol.uppercased())", body: Body(messages: messages))
    }

    func streamGeneralChat(messages: [ChatMessage]) async throws -> AsyncThrowingStream<String, Error> {
        struct Body: Encodable { let messages: [ChatMessage] }
        return try await eventStream(path: "/api/chat/general", body: Body(messages: messages))
    }

    private func eventStream<Body: Encodable>(
        path: String,
        body: Body
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let baseURL = AppConfiguration.shared.apiBaseURL else { throw ClientError.notConfigured }
        var cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        if baseURL.path.hasSuffix("/api"), cleanPath.hasPrefix("api/") { cleanPath.removeFirst(4) }
        let url = baseURL.appending(path: cleanPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let session = try? await SupabaseProvider.client.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        let streamRequest = request

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: streamRequest)
                    guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
                    guard 200..<300 ~= http.statusCode else {
                        var errorData = Data()
                        for try await byte in bytes { errorData.append(byte) }
                        throw self.mapError(status: http.statusCode, data: errorData)
                    }
                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        continuation.yield(payload)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

extension APIClient {
    func market() async throws -> MarketContext {
        try await get("/api/market")
    }

    func search(_ query: String) async throws -> [StockSearchResult] {
        try await get("/api/search", queryItems: [URLQueryItem(name: "q", value: query)])
    }

    func history(symbol: String, period: String) async throws -> [PriceBar] {
        try await get(
            "/api/history/\(symbol.uppercased())",
            queryItems: [URLQueryItem(name: "period", value: period)]
        )
    }

    func metrics(symbol: String) async throws -> StockMetrics {
        try await get("/api/metrics/\(symbol.uppercased())")
    }

    func analysis(symbol: String, action: String = "buy") async throws -> AnalysisResult {
        try await get(
            "/api/analyze/\(symbol.uppercased())",
            queryItems: [URLQueryItem(name: "action", value: action)]
        )
    }

    func news(symbol: String) async throws -> StockNews {
        try await get("/api/news/\(symbol.uppercased())")
    }

    func financials(symbol: String) async throws -> Financials {
        try await get("/api/financials/\(symbol.uppercased())")
    }

    func screenerSignals() async throws -> [ScreenerSignal] {
        try await get("/api/universe/signals", queryItems: [URLQueryItem(name: "limit", value: "60")])
    }

    func portfolio() async throws -> [PortfolioHolding] { try await get("/api/portfolio") }

    func addHolding(_ holding: AddHoldingBody) async throws {
        struct Response: Decodable { let symbol: String }
        let _: Response = try await send("/api/portfolio", method: "POST", body: holding)
    }

    func deleteHolding(symbol: String) async throws {
        try await delete("/api/portfolio/\(symbol)")
    }

    func sellHolding(symbol: String, sellPrice: Double, sellDate: String? = nil) async throws {
        // Fire and forget — we don't need to decode the response.
        // The holding is already removed from local state before this call.
        let body = SellHoldingBody(sellPrice: sellPrice, sellDate: sellDate)
        let data = try await request(
            path: "/api/portfolio/\(symbol.uppercased())/sell",
            method: "POST",
            body: encoder.encode(body)
        )
        // Ignore the response body entirely — success is any 2xx status
        _ = data
    }

    func soldPositions() async throws -> [SoldPosition] {
        try await get("/api/portfolio/sold")
    }

    func profile() async throws -> InvestmentProfile { try await get("/api/profile") }
    func saveProfile(_ profile: InvestmentProfile) async throws -> InvestmentProfile { try await send("/api/profile", method: "PUT", body: profile) }
    func alerts() async throws -> [UserAlert] { try await get("/api/alerts") }
    func createAlert(symbol: String, type: String, threshold: Double?) async throws -> UserAlert {
        struct Body: Encodable { let symbol: String; let alert_type: String; let threshold: Double? }
        return try await send("/api/alerts", method: "POST", body: Body(symbol: symbol, alert_type: type, threshold: threshold))
    }
    func toggleAlert(id: String, enabled: Bool) async throws -> UserAlert {
        struct Body: Encodable { let enabled: Bool }
        return try await send("/api/alerts/\(id)", method: "PATCH", body: Body(enabled: enabled))
    }
    func deleteAlert(id: String) async throws { try await delete("/api/alerts/\(id)") }
    func criteria() async throws -> CriteriaConfiguration { try await get("/api/criteria") }
    func saveCriteria(_ criteria: CriteriaConfiguration) async throws {
        struct Response: Decodable { let saved: Bool }
        let _: Response = try await send("/api/criteria", method: "PUT", body: criteria)
    }
    func brokerageStatus() async throws -> BrokerageStatus { try await get("/api/plaid/status") }
    func plaidLinkToken() async throws -> String {
        struct Empty: Encodable {}
        let response: PlaidLinkToken = try await send("/api/plaid/link-token", method: "POST", body: Empty())
        return response.linkToken
    }
    func exchangePlaidToken(_ token: String, institution: String) async throws -> PlaidExchangeResult {
        struct Body: Encodable { let public_token: String; let institution_name: String }
        return try await send("/api/plaid/exchange", method: "POST", body: Body(public_token: token, institution_name: institution))
    }
    func disconnectBrokerage(id: String, removeHoldings: Bool) async throws {
        try await delete("/api/plaid/disconnect/\(id)", queryItems: [URLQueryItem(name: "remove_holdings", value: removeHoldings ? "true" : "false")])
    }

    func credits() async throws -> CreditsStatus { try await get("/api/credits") }
    func setAPIKey(_ key: String) async throws -> CreditsStatus {
        struct Body: Encodable { let api_key: String }
        return try await send("/api/credits/key", method: "POST", body: Body(api_key: key))
    }
    func removeAPIKey() async throws -> CreditsStatus {
        let data = try await request(path: "/api/credits/key", method: "DELETE")
        return try decoder.decode(CreditsStatus.self, from: data)
    }
    func deleteAccount() async throws {
        _ = try await request(path: "/api/account", method: "DELETE")
    }
}
