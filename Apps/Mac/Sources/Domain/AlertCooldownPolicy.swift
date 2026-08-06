import Foundation

/// 报警冷却写入策略：仅当至少一条通道实际成功时才进入冷却。
public enum AlertCooldownPolicy: Sendable {
    /// Mac 通知成功 **或** 邮件成功 → 进入冷却；两者都失败 → 不进冷却（可立即重试）。
    public static func shouldEnterCooldown(notified: Bool, emailed: Bool) -> Bool {
        notified || emailed
    }
}
