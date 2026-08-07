import Foundation

/// 智余 · SmartBalance 品牌常量。
public enum Brand: Sendable {
    public static let nameCN = "智余"
    public static let nameEN = "SmartBalance"
    public static let displayTitle = nameCN
    public static let taglineCN = "API 查询 · Mac 通知 · 邮件报警"
    public static let taglineEN = "API · Mac notify · email alerts"
    /// 设置「关于」卡片一句话
    public static let aboutLine = "\(nameCN) \(nameEN) · 监控各平台 API / Token 余额"
    /// 0.2.22+ 换新 id，强制通知中心丢弃旧「余」字标缓存（设置仍在 Application Support/SmartBalance）
    public static let bundleId = "com.smartbalance.zhiyu"
}
