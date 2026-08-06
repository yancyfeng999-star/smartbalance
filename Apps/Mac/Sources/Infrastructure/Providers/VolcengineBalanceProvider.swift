import Foundation
import Domain

/// 火山引擎费用中心余额。
///
/// `POST https://billing.volcengineapi.com/?Action=QueryBalanceAcct&Version=2022-01-01`
/// 鉴权：Access Key ID + Secret Access Key（OpenAPI HMAC-SHA256 签名）
/// 文档 / API Explorer：账单中心 · QueryBalanceAcct
///
/// 密钥在 vault 中按两行保存：`AK\nSK`（见 `VolcengineSigner.packCredentials`）。
public struct VolcengineBalanceProvider: BalanceProvider {
    public let kind: ProviderKind = .volcengine
    private let http: any HTTPClient

    public static let host = "billing.volcengineapi.com"
    public static let service = "billing"
    public static let region = "cn-beijing"
    public static let action = "QueryBalanceAcct"
    public static let version = "2022-01-01"
    public static let contentType = "application/json"

    public init(http: any HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }

    public func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot {
        guard let pair = VolcengineSigner.unpackCredentials(credentials.apiKey) else {
            throw BalanceProviderError.missingCredential
        }

        let body = Data("{}".utf8)
        let signed = try VolcengineSigner.sign(
            method: "POST",
            host: Self.host,
            path: "/",
            query: [
                "Action": Self.action,
                "Version": Self.version,
            ],
            body: body,
            accessKeyId: pair.accessKeyId,
            secretAccessKey: pair.secretAccessKey,
            service: Self.service,
            region: Self.region,
            contentType: Self.contentType
        )

        var request = URLRequest(url: signed.url)
        request.httpMethod = signed.method
        request.httpBody = signed.body
        request.timeoutInterval = 30
        for (k, v) in signed.headers {
            request.setValue(v, forHTTPHeaderField: k)
        }

        let (data, response) = try await http.data(for: request)
        let code = response.statusCode
        let bodyText = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(code) else {
            throw BalanceProviderError.httpStatus(code, bodyText)
        }

        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        // 火山错误：ResponseMetadata.Error
        if let meta = root["ResponseMetadata"] as? [String: Any],
           let err = meta["Error"] as? [String: Any] {
            let msg = (err["Message"] as? String)
                ?? (err["Code"] as? String)
                ?? "QueryBalanceAcct 失败"
            throw BalanceProviderError.providerMessage(msg)
        }

        let result = (root["Result"] as? [String: Any]) ?? root
        let available = parseMoney(result["AvailableBalance"])
        let cash = parseMoney(result["CashBalance"])
        let freeze = parseMoney(result["FreezeAmount"])
        let credit = parseMoney(result["CreditLimit"])
        let arrears = parseMoney(result["ArrearsBalance"])
        let accountID = result["AccountID"] ?? result["AccountId"]

        guard let amount = available ?? cash else {
            throw BalanceProviderError.decodeFailed("无 AvailableBalance / CashBalance：\(bodyText.prefix(200))")
        }

        let amountThreshold = account.alertThreshold ?? 10
        let percentThreshold = account.alertPercentThreshold ?? 20
        let status = BalanceSnapshot.resolveStatus(
            amount: amount,
            remainingPercent: nil,
            amountThreshold: amountThreshold,
            percentThreshold: percentThreshold
        )

        var detailParts: [String] = []
        if let accountID {
            detailParts.append("账号 \(accountID)")
        }
        if let cash {
            detailParts.append(String(format: "现金 ¥%.2f", cash))
        }
        if let freeze, freeze > 0 {
            detailParts.append(String(format: "冻结 ¥%.2f", freeze))
        }
        if let credit, credit > 0 {
            detailParts.append(String(format: "信控 ¥%.2f", credit))
        }
        if let arrears, arrears > 0 {
            detailParts.append(String(format: "欠费 ¥%.2f", arrears))
        }

        return BalanceSnapshot(
            accountId: account.id,
            providerKind: .volcengine,
            displayName: account.title,
            source: .api,
            amount: amount,
            unit: "¥",
            used: nil,
            total: nil,
            remainingPercent: nil,
            status: status,
            detail: detailParts.isEmpty ? "可用余额" : detailParts.joined(separator: " · ")
        )
    }

    private func parseMoney(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String {
            let cleaned = s.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: "")
            return Double(cleaned)
        }
        return nil
    }
}
