import Foundation
import Domain

/// 小米 MiMo 开放平台 API 钱包余额。
///
/// `GET https://platform.xiaomimimo.com/api/v1/balance`
/// Cookie: `api-platform_serviceToken=…; userId=…`
///
/// 只查 API 充值余额，不查 Token Plan。
public struct MiMoBalanceProvider: BalanceProvider {
    public let kind: ProviderKind = .mimo
    private let http: any HTTPClient

    public init(http: any HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }

    public func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot {
        let resolved = SessionCookieParser.resolveMiMo(
            secret: credentials.apiKey,
            userId: credentials.userId ?? account.userId
        )
        guard !resolved.token.isEmpty else { throw BalanceProviderError.missingCredential }
        let userId = (resolved.userId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty else { throw BalanceProviderError.missingUserId }

        let base = (credentials.baseURL ?? account.baseURL ?? kind.defaultBaseURL ?? "https://platform.xiaomimimo.com")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/balance") else {
            throw BalanceProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://platform.xiaomimimo.com", forHTTPHeaderField: "Origin")
        request.setValue("https://platform.xiaomimimo.com/console/balance", forHTTPHeaderField: "Referer")
        request.setValue(
            "api-platform_serviceToken=\(resolved.token); userId=\(userId)",
            forHTTPHeaderField: "Cookie"
        )
        request.timeoutInterval = 20

        let (data, response) = try await http.data(for: request)
        let code = response.statusCode
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(code) else {
            if code == 401 || code == 403 {
                throw BalanceProviderError.providerMessage("登录已失效，请重新从浏览器复制 Cookie")
            }
            throw BalanceProviderError.httpStatus(code, body)
        }

        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let biz = number(root["code"]), biz != 0 {
            let msg = (root["message"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "业务错误 code=\(Int(biz))"
            throw BalanceProviderError.providerMessage(msg)
        }

        let dataNode = (root["data"] as? [String: Any]) ?? [:]
        guard let amount = number(dataNode["balance"]) ?? number(dataNode["cashBalance"]) else {
            throw BalanceProviderError.decodeFailed("缺少 data.balance")
        }

        let cash = number(dataNode["cashBalance"])
        let gift = number(dataNode["giftBalance"])
        let frozen = number(dataNode["frozenBalance"])
        let currency = (dataNode["currency"] as? String) ?? "CNY"
        let unit = (currency.uppercased() == "CNY" || currency == "¥") ? "¥" : currency

        let threshold = account.alertThreshold ?? 10
        let status = BalanceSnapshot.resolveStatus(
            amount: amount,
            remainingPercent: nil,
            amountThreshold: threshold,
            percentThreshold: 20
        )

        var detailParts: [String] = ["API 余额"]
        if let cash { detailParts.append(String(format: "现金 %.2f", cash)) }
        if let gift, gift > 0 { detailParts.append(String(format: "赠送 %.2f", gift)) }
        if let frozen, frozen > 0 { detailParts.append(String(format: "冻结 %.2f", frozen)) }
        detailParts.append("UID \(userId)")

        return BalanceSnapshot(
            accountId: account.id,
            providerKind: .mimo,
            displayName: account.title,
            source: .api,
            amount: amount,
            unit: unit,
            status: status,
            detail: detailParts.joined(separator: " · ")
        )
    }

    private func number(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }
}
