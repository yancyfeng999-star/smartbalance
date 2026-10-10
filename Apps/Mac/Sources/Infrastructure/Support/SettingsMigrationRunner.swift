import Foundation
import Domain

/// 纯迁移链入口：不读 Keychain、不发起网络、不删除旧文件。
public struct SettingsMigrationRunner: Sendable {
    public init() {}

    public func migrate(data: Data, now: Date = Date()) throws -> SettingsMigrationOutcome {
        try SettingsMigration.migrate(data: data, now: now)
    }

    public func evaluateCompatibility(
        data: Data?,
        usageHealth: UsageStorageHealth,
        notification: NotificationAuthorizationState,
        now: Date = Date()
    ) -> CompatibilityMigrationResult {
        guard let data else {
            return CompatibilityMigrationResult.inspect(
                settingsOutcome: nil,
                usageHealth: usageHealth,
                notification: notification
            )
        }
        do {
            let outcome = try migrate(data: data, now: now)
            return CompatibilityMigrationResult.inspect(
                settingsOutcome: outcome,
                usageHealth: usageHealth,
                notification: notification
            )
        } catch let error as SettingsMigrationError {
            return CompatibilityMigrationResult.inspect(
                settingsOutcome: nil,
                settingsError: error,
                usageHealth: usageHealth,
                notification: notification
            )
        } catch {
            return CompatibilityMigrationResult.inspect(
                settingsOutcome: nil,
                settingsError: .invalidJSON,
                usageHealth: usageHealth,
                notification: notification
            )
        }
    }
}
