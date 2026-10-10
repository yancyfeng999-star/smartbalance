import XCTest
@testable import Domain

final class WalletAccountMigrationTests: XCTestCase {
    func testStoredMiniMaxDefaultsUseCurrentWalletDomainAfterUpgrade() throws {
        let account = try roundTrip(BalanceAccount(
            kind: .minimax,
            baseURL: "https://www.minimaxi.com/",
            consoleURL: "https://platform.minimaxi.com/console/recharge-records"
        ))

        XCTAssertEqual(account.baseURL, "https://www.minimax.cn")
        XCTAssertEqual(account.resolvedConsoleURL, "https://platform.minimax.cn/console/recharge-records")
    }

    func testStoredApinebulaDefaultsUseCurrentWalletDomainAfterUpgrade() throws {
        let account = try roundTrip(BalanceAccount(
            kind: .apinebula,
            baseURL: "https://apinebula.ai",
            consoleURL: "https://apinebula.ai/zh/console/topup"
        ))

        XCTAssertEqual(account.baseURL, "https://apinebula.com")
        XCTAssertEqual(account.resolvedConsoleURL, "https://apinebula.com/zh/console/topup")
    }

    func testCustomWalletURLsRemainUnchanged() throws {
        for kind in [ProviderKind.minimax, .apinebula] {
            let account = try roundTrip(BalanceAccount(
                kind: kind,
                baseURL: "https://custom.example.test/api",
                consoleURL: "https://custom.example.test/wallet"
            ))

            XCTAssertEqual(account.baseURL, "https://custom.example.test/api")
            XCTAssertEqual(account.consoleURL, "https://custom.example.test/wallet")
        }
    }

    private func roundTrip(_ account: BalanceAccount) throws -> BalanceAccount {
        try JSONDecoder().decode(BalanceAccount.self, from: JSONEncoder().encode(account))
    }
}
