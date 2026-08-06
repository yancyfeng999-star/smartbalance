import XCTest
@testable import Infrastructure
@testable import Domain

final class ProviderRegistryTests: XCTestCase {
    func testRegistryReturnsProviders() {
        XCTAssertEqual(ProviderRegistry.provider(for: .deepseek).kind, .deepseek)
        XCTAssertEqual(ProviderRegistry.provider(for: .newapi).kind, .newapi)
    }

    func testDeepSeekMissingKey() async {
        let p = DeepSeekBalanceProvider()
        let account = BalanceAccount(kind: .deepseek)
        do {
            _ = try await p.fetchBalance(account: account, credentials: ProviderCredentials(apiKey: ""))
            XCTFail("expected error")
        } catch {
            // ok
        }
    }
}
