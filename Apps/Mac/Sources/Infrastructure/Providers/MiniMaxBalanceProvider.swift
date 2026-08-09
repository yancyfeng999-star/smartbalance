import Foundation
import Domain

/// MiniMax 开放平台 API 钱包余额（充值余额，非 Token Plan）。
///
/// `GET https://www.minimaxi.com/account/query_balance`
/// Cookie: `_token=<JWT>`
public struct MiniMaxBalanceProvider: BalanceProvider {
    public let kind: ProviderKind = .minimax
    private let http: any HTTPClient

    public init(http: any HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }

    public func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot {
        let token = SessionCookieParser.resolveMiniMaxToken(secret: credentials.apiKey)
        guard !token.isEmpty else { throw BalanceProviderError.missingCredential }
        // 开放平台查询余额需要 X-Group-Id（可从 Cookie minimax_group_id_v2 或账号 userId 带入）
        let groupId = (
            SessionCookieParser.value(named: "minimax_group_id_v2", in: credentials.apiKey)
                ?? credentials.userId
                ?? account.userId
        )?.trimmingCharacters(in: .whitespacesAndNewlines)

        let base = (credentials.baseURL ?? account.baseURL ?? kind.defaultBaseURL ?? "https://www.minimaxi.com")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/account/query_balance") else {
            throw BalanceProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://platform.minimaxi.com", forHTTPHeaderField: "Origin")
        request.setValue("https://platform.minimaxi.com/console/recharge-records", forHTTPHeaderField: "Referer")
        request.setValue("_token=\(token)", forHTTPHeaderField: "Cookie")
        if let groupId, !groupId.isEmpty {
            request.setValue(groupId, forHTTPHeaderField: "X-Group-Id")
        }
        request.timeoutInterval = 20

        let (data, response) = try await http.data(for: request)
        let code = response.statusCode
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(code) else {
            if code == 401 || code == 403 {
                throw BalanceProviderError.providerMessage("登录已失效，请重新从浏览器复制 _token")
            }
            throw BalanceProviderError.httpStatus(code, body)
        }

        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let baseResp = root["base_resp"] as? [String: Any] {
            let statusCode = number(baseResp["status_code"]).map { Int($0) } ?? 0
            if statusCode == 1004 {
                throw BalanceProviderError.providerMessage("登录已失效，请重新从浏览器复制 _token")
            }
            if statusCode != 0 {
                let msg = (baseResp["status_msg"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? "业务错误 status_code=\(statusCode)"
                throw BalanceProviderError.providerMessage(msg)
            }
        }

        guard let amount = number(root["available_amount"]) ?? number(root["cash_balance"]) else {
            throw BalanceProviderError.decodeFailed("缺少 available_amount")
        }

        let cash = number(root["cash_balance"])
        let voucher = number(root["voucher_balance"])
        let credit = number(root["credit_balance"])
        let alert = number(root["balance_alert_threshold"])

        let threshold = account.alertThreshold ?? 10
        let status = BalanceSnapshot.resolveStatus(
            amount: amount,
            remainingPercent: nil,
            amountThreshold: threshold,
            percentThreshold: 20
        )

        var detailParts: [String] = ["API 余额"]
        if let cash { detailParts.append(String(format: "现金 %.2f", cash)) }
        if let voucher, voucher > 0 { detailParts.append(String(format: "券 %.2f", voucher)) }
        if let credit, credit > 0 { detailParts.append(String(format: "信用 %.2f", credit)) }
        if let alert { detailParts.append(String(format: "平台预警线 %.0f", alert)) }

        return BalanceSnapshot(
            accountId: account.id,
            providerKind: .minimax,
            displayName: account.title,
            source: .api,
            amount: amount,
            unit: "¥",
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
