import Foundation
import Domain

/// OpenRouter 账户 credits 余额。
/// 文档：GET https://openrouter.ai/api/v1/credits
/// Header: Authorization: Bearer <key>
/// 响应：`{ "data": { "total_credits": number, "total_usage": number } }`
/// 剩余 = total_credits − total_usage（单位与 credits 一致，按 USD 展示）。
public struct OpenRouterBalanceProvider: BalanceProvider {
    public let kind: ProviderKind = .openrouter
    private let http: any HTTPClient

    public init(http: any HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }

    public func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot {
        guard !credentials.apiKey.isEmpty else { throw BalanceProviderError.missingCredential }

        let base = (credentials.baseURL ?? account.baseURL ?? kind.defaultBaseURL ?? "https://openrouter.ai/api/v1")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/credits") else {
            throw BalanceProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let (data, response) = try await http.data(for: request)
        let code = response.statusCode
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(code) else {
            throw BalanceProviderError.httpStatus(code, body)
        }

        let decoded: OpenRouterCreditsResponse
        do {
            decoded = try JSONDecoder().decode(OpenRouterCreditsResponse.self, from: data)
        } catch {
            throw BalanceProviderError.decodeFailed(error.localizedDescription)
        }

        let totalCredits = decoded.data.totalCredits
        let totalUsage = decoded.data.totalUsage
        let remaining = totalCredits - totalUsage

        let remainingPercent: Double? = {
            guard totalCredits > 0 else { return remaining <= 0 ? 0 : nil }
            return max(0, min(100, (remaining / totalCredits) * 100))
        }()

        let threshold = account.alertThreshold ?? 5
        let percentThreshold = account.alertPercentThreshold ?? 20
        let status = BalanceSnapshot.resolveStatus(
            amount: remaining,
            remainingPercent: remainingPercent,
            amountThreshold: threshold,
            percentThreshold: percentThreshold
        )

        let detail = String(
            format: "充值 %.2f · 已用 %.2f · 剩余 %.2f",
            totalCredits,
            totalUsage,
            remaining
        )

        return BalanceSnapshot(
            accountId: account.id,
            providerKind: .openrouter,
            displayName: account.title,
            source: .api,
            amount: remaining,
            unit: "USD",
            used: totalUsage,
            total: totalCredits,
            remainingPercent: remainingPercent,
            status: status,
            detail: detail
        )
    }
}

// MARK: - DTO

/// OpenRouter GET /api/v1/credits envelope.
/// Fixture (official docs example):
/// `{"data":{"total_credits":100.5,"total_usage":25.75}}` → remaining 74.75
private struct OpenRouterCreditsResponse: Decodable {
    let data: CreditsData

    struct CreditsData: Decodable {
        let totalCredits: Double
        let totalUsage: Double

        enum CodingKeys: String, CodingKey {
            case totalCredits = "total_credits"
            case totalUsage = "total_usage"
        }
    }
}
