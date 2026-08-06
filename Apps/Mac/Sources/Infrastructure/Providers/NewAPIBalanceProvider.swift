import Foundation
import Domain

/// New-API / one-api 兼容中转站余额。
/// 典型：GET {base}/api/user/self  Header: Authorization: Bearer <token> 或 {token}
public struct NewAPIBalanceProvider: BalanceProvider {
    public let kind: ProviderKind = .newapi

    public init() {}

    public func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot {
        guard !credentials.apiKey.isEmpty else { throw BalanceProviderError.missingCredential }
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
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("New-API", forHTTPHeaderField: "New-API-User")
        request.timeoutInterval = 20

        var (data, response) = try await URLSession.shared.data(for: request)
        var code = (response as? HTTPURLResponse)?.statusCode ?? 0

        // 部分站点只要裸 token。
        if code == 401 || code == 403 {
            var retry = request
            retry.setValue(credentials.apiKey, forHTTPHeaderField: "Authorization")
            (data, response) = try await URLSession.shared.data(for: retry)
            code = (response as? HTTPURLResponse)?.statusCode ?? 0
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(code) else {
            throw BalanceProviderError.httpStatus(code, body)
        }

        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let dataNode = (root?["data"] as? [String: Any]) ?? root ?? [:]

        // quota 常为「点」，展示时 / 500000 ≈ 美元（New-API 常见换算），同时保留原始点。
        let quota = number(dataNode["quota"]) ?? number(dataNode["Quota"])
        let usedQuota = number(dataNode["used_quota"]) ?? number(dataNode["UsedQuota"])
        let unlimited = bool(dataNode["unlimited_quota"])

        let amountUSD: Double? = {
            guard let quota else { return nil }
            return quota / 500_000.0
        }()

        let remainingPercent: Double? = {
            guard let quota, let used = usedQuota, quota + used > 0 else { return nil }
            let total = quota + used
            return max(0, min(100, (quota / total) * 100))
        }()

        let amountThreshold = account.alertThreshold ?? 1
        let percentThreshold = account.alertPercentThreshold ?? 20
        let status: BalanceStatus = {
            if unlimited == true { return .healthy }
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
        if let quota { detailParts.append(String(format: "剩余点数 %.0f", quota)) }
        if let usedQuota { detailParts.append(String(format: "已用 %.0f", usedQuota)) }
        if unlimited == true { detailParts.append("无限额度") }

        return BalanceSnapshot(
            accountId: account.id,
            providerKind: .newapi,
            displayName: account.title,
            source: .api,
            amount: amountUSD,
            unit: "USD",
            used: usedQuota,
            total: (quota != nil && usedQuota != nil) ? (quota! + usedQuota!) : nil,
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
