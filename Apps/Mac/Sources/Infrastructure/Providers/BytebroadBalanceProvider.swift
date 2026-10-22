import Foundation
import CoreFoundation
import Domain

/// Bytebroad CNY wallet. Observed on the official console, 2026-10-21:
/// GET /api/user/self, session + New-Api-User; /api/status reports
/// quota_per_unit=500000, quota_display_type=CNY, usd_exchange_rate=1.
/// This conversion applies ONLY to this fixed site, not arbitrary New-API sites.
public struct BytebroadBalanceProvider: BalanceProvider {
    public let kind: ProviderKind = .bytebroad
    private let http: any HTTPClient
    private static let base = "https://token.bytebroad.com.cn"

    public init(http: (any HTTPClient)? = nil) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        self.http = http ?? URLSessionHTTPClient(session: URLSession(
            configuration: config, delegate: BytebroadNoRedirects(), delegateQueue: nil
        ))
    }

    public func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot {
        let resolved = SessionCookieParser.resolveApinebula(
            secret: credentials.apiKey, userId: credentials.userId ?? account.userId
        )
        let session = resolved.session
        guard !session.isEmpty, !session.hasPrefix("sk-"),
              !session.contains("\r"), !session.contains("\n") else {
            throw BalanceProviderError.missingCredential
        }
        let explicitUID = (credentials.userId ?? account.userId)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userID = (explicitUID?.isEmpty == false ? explicitUID : nil)
            ?? SessionCookieParser.extractNewAPISessionUserId(fromSession: session)
        guard let rawUID = userID, let numericUID = UInt64(rawUID), numericUID > 0 else {
            throw BalanceProviderError.missingUserId
        }
        let uid = String(numericUID)
        // Ignore custom URL overrides; never send this Cookie to another host.
        var request = URLRequest(url: URL(string: Self.base + "/api/user/self")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("session=\(session)", forHTTPHeaderField: "Cookie")
        request.setValue(uid, forHTTPHeaderField: "New-Api-User")
        request.setValue(Self.base, forHTTPHeaderField: "Origin")
        request.setValue(Self.base + "/wallet", forHTTPHeaderField: "Referer")

        let (data, response) = try await http.data(for: request)
        if response.statusCode == 401 || response.statusCode == 403 {
            throw BalanceProviderError.authenticationExpired
        }
        guard (200...299).contains(response.statusCode) else {
            // The body may contain private upstream details. Never surface it.
            throw BalanceProviderError.httpStatus(response.statusCode, "钱包查询失败，请稍后重试")
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = root["success"] as? Bool else {
            throw BalanceProviderError.decodeFailed("钱包响应格式不正确")
        }
        guard success else {
            let message = (root["message"] as? String ?? "").lowercased()
            if ["未登录", "登录失效", "登录已过期", "登录状态", "无权进行此操作", "unauthorized", "not logged", "invalid session", "session expired"].contains(where: message.contains) {
                throw BalanceProviderError.authenticationExpired
            }
            throw BalanceProviderError.providerMessage("Bytebroad 钱包查询失败，请稍后重试")
        }
        guard let node = root["data"] as? [String: Any],
              let quota = Self.number(node["quota"]) else {
            throw BalanceProviderError.decodeFailed("缺少有效的钱包余额 quota")
        }
        if let returnedID = Self.number(node["id"]), returnedID != Double(numericUID) {
            throw BalanceProviderError.providerMessage("浏览器账号与钱包账号不一致，请重新连接")
        }
        if let currency = node["currency"] as? String, !["CNY", "¥", "￥"].contains(currency.uppercased()) {
            throw BalanceProviderError.decodeFailed("钱包货币与人民币配置不一致")
        }
        let amount = quota / 500_000
        let used = Self.number(node["used_quota"]).flatMap { $0 >= 0 ? $0 / 500_000 : nil }
        let total = used.map { amount + $0 }.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        return BalanceSnapshot(
            accountId: account.id, providerKind: kind, displayName: account.title,
            amount: amount, unit: "¥", used: used, total: total,
            status: BalanceSnapshot.resolveStatus(amount: amount, remainingPercent: nil,
                amountThreshold: account.alertThreshold ?? 10, percentThreshold: 20),
            detail: "人民币钱包 · 浏览器会话"
        )
    }

    private static func number(_ value: Any?) -> Double? {
        let result: Double?
        if let n = value as? NSNumber {
            guard CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
            result = n.doubleValue
        }
        else if let s = value as? String { result = Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) }
        else { result = nil }
        return result.flatMap { $0.isFinite ? $0 : nil }
    }
}

private final class BytebroadNoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
