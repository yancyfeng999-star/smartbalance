import Foundation
import Domain

/// 老张 API 账户余额。
/// 文档：GET https://api2.laozhang.ai/api/user/self
/// Header: Authorization: <AccessToken>（裸令牌，不加 Bearer）
/// 注意：是「系统令牌 AccessToken」，不是模型调用用的 sk- API Key。
/// 额度：quota / 500000 ≈ USD。
public struct LaoZhangBalanceProvider: BalanceProvider {
    public let kind: ProviderKind = .laozhang
    private let http: any HTTPClient
    private static let quotaPerUSD: Double = 500_000

    public init(http: any HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }

    public func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot {
        guard !credentials.apiKey.isEmpty else { throw BalanceProviderError.missingCredential }

        let base = (credentials.baseURL ?? account.baseURL ?? kind.defaultBaseURL ?? "https://api2.laozhang.ai")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/user/self") else {
            throw BalanceProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // 文档要求 Authorization 直接填 AccessToken，不要加 Bearer。
        request.setValue(credentials.apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        let (data, response) = try await http.data(for: request)
        let code = response.statusCode
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(code) else {
            throw BalanceProviderError.httpStatus(code, body)
        }

        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let success = root["success"] as? Bool, success == false {
            let msg = (root["message"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "查询失败"
            throw BalanceProviderError.providerMessage(msg)
        }

        let dataNode = (root["data"] as? [String: Any]) ?? root
        let quota = number(dataNode["quota"])
        let usedQuota = number(dataNode["used_quota"])
        let requestCount = number(dataNode["request_count"])
        let group = dataNode["group"] as? String
        let username = (dataNode["username"] as? String) ?? (dataNode["display_name"] as? String)

        guard let quota else {
            throw BalanceProviderError.decodeFailed("缺少 data.quota")
        }

        let amountUSD = quota / Self.quotaPerUSD
        let usedUSD = usedQuota.map { $0 / Self.quotaPerUSD }
        let remainingPercent: Double? = {
            guard let used = usedQuota, quota + used > 0 else { return nil }
            return max(0, min(100, (quota / (quota + used)) * 100))
        }()

        let threshold = account.alertThreshold ?? 1
        let percentThreshold = account.alertPercentThreshold ?? 20
        let status = BalanceSnapshot.resolveStatus(
            amount: amountUSD,
            remainingPercent: remainingPercent,
            amountThreshold: threshold,
            percentThreshold: percentThreshold
        )

        var detailParts: [String] = []
        if let username { detailParts.append(username) }
        if let group, !group.isEmpty { detailParts.append("分组 \(group)") }
        detailParts.append(String(format: "剩余点数 %.0f", quota))
        if let usedQuota { detailParts.append(String(format: "已用 %.0f", usedQuota)) }
        if let requestCount { detailParts.append(String(format: "请求 %.0f 次", requestCount)) }

        return BalanceSnapshot(
            accountId: account.id,
            providerKind: .laozhang,
            displayName: account.title,
            source: .api,
            amount: amountUSD,
            unit: "USD",
            used: usedUSD,
            total: usedUSD.map { amountUSD + $0 },
            remainingPercent: remainingPercent,
            status: status,
            detail: detailParts.joined(separator: " · ")
        )
    }

    private func number(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s) }
        return nil
    }
}
