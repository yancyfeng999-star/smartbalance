import Foundation
import Domain

/// DMXAPI 账户余额。
/// 文档：GET https://www.dmxapi.cn/api/user/self
/// Headers:
///   Authorization: Bearer <系统访问令牌>
///   Dmx-Api-User: <用户 ID>
/// 注意：系统访问令牌 ≠ 模型 sk- Key；用户 ID 在个人资料页。
/// 额度：quota / 500000 ≈ CNY。
public struct DMXAPIBalanceProvider: BalanceProvider {
    public let kind: ProviderKind = .dmxapi
    private let http: any HTTPClient
    private static let quotaPerCNY: Double = 500_000

    public init(http: any HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }

    public func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot {
        guard !credentials.apiKey.isEmpty else { throw BalanceProviderError.missingCredential }
        let userId = (credentials.userId ?? account.userId ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty else { throw BalanceProviderError.missingUserId }

        let base = (credentials.baseURL ?? account.baseURL ?? kind.defaultBaseURL ?? "https://www.dmxapi.cn")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/user/self") else {
            throw BalanceProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(userId, forHTTPHeaderField: "Dmx-Api-User")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await http.data(for: request)
        let code = response.statusCode
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(code) else {
            throw BalanceProviderError.httpStatus(code, body)
        }

        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let success = root["success"] as? Bool, success == false {
            let msg = (root["message"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "获取用户信息失败"
            throw BalanceProviderError.providerMessage(msg)
        }

        let dataNode = (root["data"] as? [String: Any]) ?? root
        let quota = number(dataNode["quota"])
        let usedQuota = number(dataNode["used_quota"])
        let username = (dataNode["username"] as? String) ?? (dataNode["display_name"] as? String)

        guard let quota else {
            throw BalanceProviderError.decodeFailed("缺少 data.quota")
        }

        let amountCNY = quota / Self.quotaPerCNY
        let usedCNY = usedQuota.map { $0 / Self.quotaPerCNY }
        let remainingPercent: Double? = {
            guard let used = usedQuota, quota + used > 0 else { return nil }
            return max(0, min(100, (quota / (quota + used)) * 100))
        }()

        let threshold = account.alertThreshold ?? 1
        let percentThreshold = account.alertPercentThreshold ?? 20
        let status = BalanceSnapshot.resolveStatus(
            amount: amountCNY,
            remainingPercent: remainingPercent,
            amountThreshold: threshold,
            percentThreshold: percentThreshold
        )

        var detailParts: [String] = []
        if let username { detailParts.append(username) }
        detailParts.append("UID \(userId)")
        detailParts.append(String(format: "剩余点数 %.0f", quota))
        if let usedQuota { detailParts.append(String(format: "已用 %.0f", usedQuota)) }

        return BalanceSnapshot(
            accountId: account.id,
            providerKind: .dmxapi,
            displayName: account.title,
            source: .api,
            amount: amountCNY,
            unit: "¥",
            used: usedCNY,
            total: usedCNY.map { amountCNY + $0 },
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
