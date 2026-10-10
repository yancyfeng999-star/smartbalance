import Foundation
import Domain

public enum ProviderRegistry {
    public static func provider(for kind: ProviderKind) -> any BalanceProvider {
        switch kind {
        case .deepseek: DeepSeekBalanceProvider()
        case .newapi: NewAPIBalanceProvider()
        case .openrouter: OpenRouterBalanceProvider()
        case .viraltok: ViralTokBalanceProvider()
        case .laozhang: LaoZhangBalanceProvider()
        case .dmxapi: DMXAPIBalanceProvider()
        case .kimi: KimiBalanceProvider()
        case .volcengine: VolcengineBalanceProvider()
        case .mimo: MiMoBalanceProvider()
        case .minimax: MiniMaxBalanceProvider()
        case .apinebula: ApinebulaBalanceProvider()
        case .unsupported: UnsupportedBalanceProvider()
        }
    }
}

public struct UnsupportedBalanceProvider: BalanceProvider {
    public let kind: ProviderKind = .unsupported

    public init() {}

    public func fetchBalance(
        account: BalanceAccount,
        credentials: ProviderCredentials
    ) async throws -> BalanceSnapshot {
        BalanceSnapshot(
            accountId: account.id,
            providerKind: account.kind,
            displayName: account.title,
            source: .api,
            unit: account.resolvedManualUnit,
            status: .setup,
            detail: "未识别的渠道，已跳过查询",
            errorMessage: "unrecognized provider"
        )
    }
}
