import Foundation
import Domain

public enum ProviderRegistry {
    public static func provider(for kind: ProviderKind) -> any BalanceProvider {
        switch kind {
        case .deepseek: DeepSeekBalanceProvider()
        case .newapi: NewAPIBalanceProvider()
        case .openrouter: OpenRouterBalanceProvider()
        case .viraltok: ViralTokBalanceProvider()
        }
    }
}
