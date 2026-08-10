import Foundation
import Domain

/// New-API / one-api 兼容中转站余额。
/// GET {base}/api/user/self
/// Headers:
///   Authorization: Bearer <系统访问令牌>（部分站点裸 token）
///   New-API-User: <用户 ID>
/// 注意：系统访问令牌 ≠ 模型 sk-；用户 ID 在个人中心 / 管理后台。
public struct NewAPIBalanceProvider: BalanceProvider {
    public let kind: ProviderKind = .newapi
    private static let quotaPerUSD: Double = 500_000
    private let http: any HTTPClient

    public init(http: any HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }

    public func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot {
        guard !credentials.apiKey.isEmpty else { throw BalanceProviderError.missingCredential }
        let userId = (credentials.userId ?? account.userId ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty else { throw BalanceProviderError.missingUserId }

        let rawBase = (credentials.baseURL ?? account.baseURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawBase.isEmpty else { throw BalanceProviderError.invalidURL }

        let base = rawBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/user/self") else {
            throw BalanceProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // New-API 常见两种写法，优先 Bearer。
        request.setValue("Bearer \(credentials.apiKey)", forHTTPHeaderField: "Authorization")
        // 与官方一致：New-API-User（HTTP 头大小写不敏感，亦兼容 New-Api-User）
        request.setValue(userId, forHTTPHeaderField: "New-API-User")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        var (data, response) = try await http.data(for: request)
        var code = response.statusCode

        // 部分站点只要裸 token。
        if code == 401 || code == 403 {
            var retry = request
            retry.setValue(credentials.apiKey, forHTTPHeaderField: "Authorization")
            (data, response) = try await http.data(for: retry)
            code = response.statusCode
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(code) else {
            throw BalanceProviderError.httpStatus(code, body)
        }

        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let success = root?["success"] as? Bool, success == false {
            let msg = (root?["message"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "获取用户信息失败"
            throw BalanceProviderError.providerMessage(msg)
        }

        let dataNode = (root?["data"] as? [String: Any]) ?? root ?? [:]

        // quota 常为「点」，展示时 / 500000 ≈ 美元（New-API 常见换算），同时保留原始点。
        let quota = number(dataNode["quota"]) ?? number(dataNode["Quota"])
        let usedQuota = number(dataNode["used_quota"]) ?? number(dataNode["UsedQuota"])
        let unlimited = bool(dataNode["unlimited_quota"])

        // Unlimited: amount nil + remainingPercent 100 so BalanceService.refreshAPI
        // re-resolveStatus stays healthy even when raw quota is 0.
        let isUnlimited = unlimited == true
        let amountUSD: Double? = {
            if isUnlimited { return nil }
            guard let quota else { return nil }
            return quota / Self.quotaPerUSD
        }()

        let usedUSD = usedQuota.map { $0 / Self.quotaPerUSD }

        let remainingPercent: Double? = {
            if isUnlimited { return 100 }
            guard let quota, let used = usedQuota, quota + used > 0 else { return nil }
            let total = quota + used
            return max(0, min(100, (quota / total) * 100))
        }()

        let amountThreshold = account.alertThreshold ?? 1
        let percentThreshold = account.alertPercentThreshold ?? 20
        let status: BalanceStatus = {
            if isUnlimited { return .healthy }
            return BalanceSnapshot.resolveStatus(
                amount: amountUSD,
                remainingPercent: remainingPercent,
                amountThreshold: amountThreshold,
                percentThreshold: percentThreshold
            )
        }()

        let username = (dataNode["username"] as? String) ?? (dataNode["display_name"] as? String)
        var detailParts: [String] = []
        if let username { detailParts.append(username) }
        detailParts.append("UID \(userId)")
        if let quota, !isUnlimited { detailParts.append(String(format: "剩余点数 %.0f", quota)) }
        if let usedQuota, !isUnlimited { detailParts.append(String(format: "已用 %.0f", usedQuota)) }
        if isUnlimited { detailParts.append("无限额度") }

        return BalanceSnapshot(
            accountId: account.id,
            providerKind: .newapi,
            displayName: account.title,
            source: .api,
            amount: amountUSD,
            unit: "USD",
            used: isUnlimited ? nil : usedUSD,
            total: (!isUnlimited && amountUSD != nil && usedUSD != nil) ? (amountUSD! + usedUSD!) : nil,
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

    private func bool(_ any: Any?) -> Bool? {
        if let b = any as? Bool { return b }
        if let i = any as? Int { return i != 0 }
        return nil
    }
}
