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
        case .mimo: ManualBalanceProvider(kind: .mimo)
        case .minimax: ManualBalanceProvider(kind: .minimax)
        case .apinebula: ManualBalanceProvider(kind: .apinebula)
        }
    }
}
