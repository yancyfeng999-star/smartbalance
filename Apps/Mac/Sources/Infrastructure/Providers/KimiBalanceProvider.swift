import Foundation
import Domain

/// Kimi / Moonshot 开放平台余额。
/// 文档：GET https://api.moonshot.cn/v1/users/me/balance
/// Header: Authorization: Bearer <MOONSHOT_API_KEY>
/// 主金额：available_balance（¥）
public struct KimiBalanceProvider: BalanceProvider {
    public let kind: ProviderKind = .kimi
    private let http: any HTTPClient

    public init(http: any HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }

    public func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot {
        guard !credentials.apiKey.isEmpty else { throw BalanceProviderError.missingCredential }

        let base = (credentials.baseURL ?? account.baseURL ?? kind.defaultBaseURL ?? "https://api.moonshot.cn")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/v1/users/me/balance") else {
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

        let decoded: KimiBalanceResponse
        do {
            decoded = try JSONDecoder().decode(KimiBalanceResponse.self, from: data)
        } catch {
            throw BalanceProviderError.decodeFailed(error.localizedDescription)
        }

        if let biz = decoded.code, biz != 0 {
            throw BalanceProviderError.providerMessage(decoded.message ?? "业务错误 code=\(biz)")
        }
        if let status = decoded.status, status == false {
            throw BalanceProviderError.providerMessage(decoded.message ?? "status=false")
        }

        guard let payload = decoded.data else {
            throw BalanceProviderError.decodeFailed("缺少 data 字段")
        }

        let available = payload.availableBalance
        let voucher = payload.voucherBalance
        let cash = payload.cashBalance

        let threshold = account.alertThreshold ?? 10
        let status = BalanceSnapshot.resolveStatus(
            amount: available,
            remainingPercent: nil,
            amountThreshold: threshold,
            percentThreshold: 20
        )

        var detailParts: [String] = []
        detailParts.append(String(format: "可用 %.4f", available))
        detailParts.append(String(format: "代金券 %.4f", voucher))
        detailParts.append(String(format: "现金 %.4f", cash))

        return BalanceSnapshot(
            accountId: account.id,
            providerKind: .kimi,
            displayName: account.title,
            source: .api,
            amount: available,
            unit: "¥",
            status: status,
            detail: detailParts.joined(separator: " · ")
        )
    }
}

// MARK: - DTO

private struct KimiBalanceResponse: Decodable {
    let code: Int?
    let status: Bool?
    let scode: String?
    let message: String?
    let data: BalanceData?

    struct BalanceData: Decodable {
        let availableBalance: Double
        let voucherBalance: Double
        let cashBalance: Double

        enum CodingKeys: String, CodingKey {
            case availableBalance = "available_balance"
            case voucherBalance = "voucher_balance"
            case cashBalance = "cash_balance"
        }
    }
}
