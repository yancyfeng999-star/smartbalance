import Foundation
import Domain

/// ViralTok（吉米 / Jimmy AI）用户账户余额。
/// 文档：GET https://api.viraltok.ai/api/open-api/v1/user/balance
/// Header: Authorization: Bearer <API_KEY>
/// 响应示例：
/// ```json
/// { "code": 20000, "msg": "ok",
///   "data": { "balance": 100.5, "used_coin": 20.3, "available": 80.2 } }
/// ```
/// 平台单位：吉米币 ≈ 美元；统一按汇率换成 **人民币** 再展示/报警。
public struct ViralTokBalanceProvider: BalanceProvider {
    public let kind: ProviderKind = .viraltok
    private let http: any HTTPClient
    /// 吉米币 → 人民币（用户约定 1 吉米币 ≈ 1 USD × 7.3）
    public static let cnyPerCoin: Double = 7.3

    public init(http: any HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }

    public func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot {
        guard !credentials.apiKey.isEmpty else { throw BalanceProviderError.missingCredential }

        let base = (credentials.baseURL ?? account.baseURL ?? kind.defaultBaseURL ?? "https://api.viraltok.ai")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/open-api/v1/user/balance") else {
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

        let decoded: ViralTokBalanceResponse
        do {
            decoded = try JSONDecoder().decode(ViralTokBalanceResponse.self, from: data)
        } catch {
            throw BalanceProviderError.decodeFailed(error.localizedDescription)
        }

        // 业务 code：20000 为成功（文档示例）
        if let biz = decoded.code, biz != 20000, biz != 0, biz != 200 {
            let msg = decoded.msg ?? "业务错误 \(biz)"
            throw BalanceProviderError.providerMessage(msg)
        }

        guard let payload = decoded.data else {
            throw BalanceProviderError.decodeFailed("缺少 data 字段")
        }

        let availableCoin = payload.available
        let balanceCoin = payload.balance
        let usedCoin = payload.usedCoin
        let rate = Self.cnyPerCoin
        let availableCNY = availableCoin * rate
        let balanceCNY = balanceCoin * rate
        let usedCNY = usedCoin * rate

        let remainingPercent: Double? = {
            guard balanceCoin > 0 else { return availableCoin <= 0 ? 0 : nil }
            return max(0, min(100, (availableCoin / balanceCoin) * 100))
        }()

        // 金额阈值按人民币（与全局默认一致）
        let threshold = account.alertThreshold ?? 10
        let percentThreshold = account.alertPercentThreshold ?? 20
        let status = BalanceSnapshot.resolveStatus(
            amount: availableCNY,
            remainingPercent: remainingPercent,
            amountThreshold: threshold,
            percentThreshold: percentThreshold
        )

        let detail = String(
            format: "可用 ¥%.2f（%.2f 吉米币）· 总额 ¥%.2f · 已用 ¥%.2f · 汇率 %.1f",
            availableCNY,
            availableCoin,
            balanceCNY,
            usedCNY,
            rate
        )

        return BalanceSnapshot(
            accountId: account.id,
            providerKind: .viraltok,
            displayName: account.title,
            source: .api,
            amount: availableCNY,
            unit: "¥",
            used: usedCNY,
            total: balanceCNY,
            remainingPercent: remainingPercent,
            status: status,
            detail: detail
        )
    }
}

// MARK: - DTO

private struct ViralTokBalanceResponse: Decodable {
    let code: Int?
    let msg: String?
    let data: BalanceData?

    struct BalanceData: Decodable {
        let balance: Double
        let usedCoin: Double
        let available: Double

        enum CodingKeys: String, CodingKey {
            case balance
            case usedCoin = "used_coin"
            case available
        }
    }
}
