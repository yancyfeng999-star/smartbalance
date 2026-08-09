import Foundation
import Domain

/// apinebula 余额（New-API 兼容站）。
/// GET https://apinebula.ai/api/user/self
///
/// **推荐**：Chrome 一键导入 session（UID 从 session 自动解析，无需手填密钥）。
/// 也可粘贴 session Cookie；系统访问令牌为高级备选。
///
/// 额度：quota / 500000 ≈ CNY。
public struct ApinebulaBalanceProvider: BalanceProvider {
    public let kind: ProviderKind = .apinebula
    private let http: any HTTPClient
    private static let quotaPerCNY: Double = 500_000
    public static let defaultAPIBase = "https://apinebula.ai"

    public init(http: any HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }

    public func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot {
        guard !credentials.apiKey.isEmpty else {
            throw BalanceProviderError.providerMessage("请先从 Chrome 导入 apinebula 登录态")
        }

        let secret = credentials.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = SessionCookieParser.resolveApinebula(
            secret: secret,
            userId: credentials.userId ?? account.userId
        )
        let sessionValue = Self.resolveSessionCookie(resolved.session) ?? Self.resolveSessionCookie(secret)
        let useSession = sessionValue != nil

        let userId = (resolved.userId ?? credentials.userId ?? account.userId ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty else {
            throw BalanceProviderError.providerMessage(
                "无法从 session 解析用户 ID。请用 Chrome 打开 apinebula 控制台后重新导入"
            )
        }

        let base = (credentials.baseURL ?? account.baseURL ?? kind.defaultBaseURL ?? Self.defaultAPIBase)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/user/self") else {
            throw BalanceProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userId, forHTTPHeaderField: "New-Api-User")
        request.setValue(userId, forHTTPHeaderField: "New-API-User")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://apinebula.ai/zh/console/topup", forHTTPHeaderField: "Referer")
        request.setValue("https://apinebula.ai", forHTTPHeaderField: "Origin")
        request.timeoutInterval = 20

        if let sessionValue {
            request.setValue("session=\(sessionValue)", forHTTPHeaderField: "Cookie")
        } else {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        var (data, response) = try await http.data(for: request)
        var code = response.statusCode

        // 部分 New-API 部署只要裸 token。
        if !useSession, code == 401 || code == 403 {
            var retry = request
            retry.setValue(secret, forHTTPHeaderField: "Authorization")
            (data, response) = try await http.data(for: retry)
            code = response.statusCode
        }

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
        let unlimited = bool(dataNode["unlimited_quota"])
        let username = (dataNode["username"] as? String) ?? (dataNode["display_name"] as? String)

        let isUnlimited = unlimited == true
        if !isUnlimited, quota == nil {
            throw BalanceProviderError.decodeFailed("缺少 data.quota")
        }

        let amountCNY: Double? = {
            if isUnlimited { return nil }
            guard let quota else { return nil }
            return quota / Self.quotaPerCNY
        }()
        let usedCNY = usedQuota.map { $0 / Self.quotaPerCNY }
        let remainingPercent: Double? = {
            if isUnlimited { return 100 }
            guard let quota, let used = usedQuota, quota + used > 0 else { return nil }
            return max(0, min(100, (quota / (quota + used)) * 100))
        }()

        let threshold = account.alertThreshold ?? 10
        let percentThreshold = account.alertPercentThreshold ?? 20
        let status: BalanceStatus = {
            if isUnlimited { return .healthy }
            return BalanceSnapshot.resolveStatus(
                amount: amountCNY,
                remainingPercent: remainingPercent,
                amountThreshold: threshold,
                percentThreshold: percentThreshold
            )
        }()

        var detailParts: [String] = []
        if let username { detailParts.append(username) }
        detailParts.append("UID \(userId)")
        if let quota, !isUnlimited {
            detailParts.append(String(format: "剩余点数 %.0f", quota))
        }
        if let usedQuota, !isUnlimited {
            detailParts.append(String(format: "已用 %.0f", usedQuota))
        }
        if isUnlimited { detailParts.append("无限额度") }
        if useSession { detailParts.append("session") }

        return BalanceSnapshot(
            accountId: account.id,
            providerKind: .apinebula,
            displayName: account.title,
            source: .api,
            amount: amountCNY,
            unit: "¥",
            used: isUnlimited ? nil : usedCNY,
            total: (!isUnlimited && amountCNY != nil && usedCNY != nil) ? (amountCNY! + usedCNY!) : nil,
            remainingPercent: remainingPercent,
            status: status,
            detail: detailParts.joined(separator: " · ")
        )
    }

    /// 从粘贴内容提取 session 值；系统令牌则返回 nil。
    static func resolveSessionCookie(_ secret: String) -> String? {
        let s = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        // 整段 Cookie：session=...
        if let v = SessionCookieParser.value(named: "session", in: s), !v.isEmpty {
            return v
        }
        if s.lowercased().hasPrefix("cookie:") {
            let rest = String(s.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            if let v = SessionCookieParser.value(named: "session", in: rest), !v.isEmpty {
                return v
            }
        }
        // 裸 session 值（控制台 cookie，通常很长且含 base64）
        if s.hasPrefix("sk-") || s.hasPrefix("sk-or-") { return nil }
        if s.count >= 80, s.contains("|") || s.contains("MTc") || s.contains("DX8") {
            return s
        }
        // 常见 New-API session：url-safe base64，长度 ≥ 100
        if s.count >= 100, s.range(of: #"^[A-Za-z0-9_\-=+/.]+$"#, options: .regularExpression) != nil {
            return s
        }
        return nil
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
