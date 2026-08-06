import Foundation
import Domain

/// 手录余额：无公开 API 的平台（小米 MiMo、MiniMax 钱包等）。
/// 金额存在 `BalanceAccount.manualAmount`，由用户对照网页录入。
public struct ManualBalanceProvider: BalanceProvider {
    public let kind: ProviderKind
    public init(kind: ProviderKind) {
        self.kind = kind
    }

    public func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot {
        let unit = account.resolvedManualUnit
        guard let amount = account.manualAmount else {
            return BalanceSnapshot(
                accountId: account.id,
                providerKind: account.kind,
                displayName: account.title,
                source: .api,
                unit: unit,
                status: .setup,
                detail: "打开后台核对后，在设置里录入金额",
                errorMessage: "尚未录入余额"
            )
        }

        let threshold = account.alertThreshold ?? 10
        let status = BalanceSnapshot.resolveStatus(
            amount: amount,
            remainingPercent: nil,
            amountThreshold: threshold,
            percentThreshold: 20
        )

        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        let when = account.manualUpdatedAt.map { f.string(from: $0) } ?? "—"
        let detail = "手录 · 更新于 \(when) · 每日提醒自行核对"

        return BalanceSnapshot(
            accountId: account.id,
            providerKind: account.kind,
            displayName: account.title,
            source: .api,
            amount: amount,
            unit: unit,
            status: status,
            detail: detail
        )
    }
}
