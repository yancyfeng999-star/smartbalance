import Foundation
import Domain

/// 纯迁移链入口：不读 Keychain、不发起网络、不删除旧文件。
public struct SettingsMigrationRunner: Sendable {
    public init() {}

    public func migrate(data: Data, now: Date = Date()) throws -> SettingsMigrationOutcome {
        try SettingsMigration.migrate(data: data, now: now)
    }
}
