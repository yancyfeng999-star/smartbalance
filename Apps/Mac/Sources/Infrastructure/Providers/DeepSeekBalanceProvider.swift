import Foundation
import Domain

/// DeepSeek 用户余额查询。
/// 文档接口：GET https://api.deepseek.com/user/balance
public struct DeepSeekBalanceProvider: BalanceProvider {
    public let kind: ProviderKind = .deepseek
    private let http: any HTTPClient

    public init(http: any HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }

    public func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot {
        guard !credentials.apiKey.isEmpty else { throw BalanceProviderError.missingCredential }

        let base = (credentials.baseURL ?? account.baseURL ?? kind.defaultBaseURL ?? "https://api.deepseek.com")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/user/balance") else {
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

        let decoded = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: data)
        guard decoded.isAvailable else {
            return BalanceSnapshot(
                accountId: account.id,
                providerKind: .deepseek,
                displayName: account.title,
                source: .api,
                status: .error,
                detail: "账户余额不可用",
                errorMessage: "is_available=false"
            )
        }

        // 优先人民币，其次美元。
        let cny = decoded.balanceInfos?.first(where: { $0.currency.uppercased() == "CNY" })
        let usd = decoded.balanceInfos?.first(where: { $0.currency.uppercased() == "USD" })
        let pick = cny ?? usd ?? decoded.balanceInfos?.first

        let amount = pick.flatMap { Double($0.totalBalance) }
        let unit: String = {
            guard let c = pick?.currency.uppercased() else { return "¥" }
            return c == "USD" ? "USD" : "¥"
        }()

        let threshold = account.alertThreshold ?? 10
        let status = BalanceSnapshot.resolveStatus(
            amount: amount,
            remainingPercent: nil,
            amountThreshold: threshold,
            percentThreshold: 20
        )

        var detailParts: [String] = []
        if let t = pick?.totalBalance { detailParts.append("总额 \(t)") }
        if let g = pick?.grantedBalance, !g.isEmpty { detailParts.append("赠送 \(g)") }
        if let top = pick?.toppedUpBalance, !top.isEmpty { detailParts.append("充值 \(top)") }

        return BalanceSnapshot(
            accountId: account.id,
            providerKind: .deepseek,
            displayName: account.title,
            source: .api,
            amount: amount,
            unit: unit,
            status: status,
            detail: detailParts.joined(separator: " · ")
        )
    }
}

// MARK: - DTO

private struct DeepSeekBalanceResponse: Decodable {
    let isAvailable: Bool
    let balanceInfos: [BalanceInfo]?

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }

    struct BalanceInfo: Decodable {
        let currency: String
        let totalBalance: String
        let grantedBalance: String?
        let toppedUpBalance: String?

        enum CodingKeys: String, CodingKey {
            case currency
            case totalBalance = "total_balance"
            case grantedBalance = "granted_balance"
            case toppedUpBalance = "topped_up_balance"
        }
    }
}
