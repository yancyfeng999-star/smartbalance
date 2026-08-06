import Foundation
import UserNotifications

/// macOS 系统通知。
public final class MacNotificationService: @unchecked Sendable {
    public static let shared = MacNotificationService()

    private let center = UNUserNotificationCenter.current()

    public init() {}

    /// 若尚未决定则请求授权；已授权返回 `true`，拒绝或失败返回 `false`。
    @MainActor
    public func requestAuthorizationIfNeeded() async -> Bool {
        let status = await authorizationStatus()
        switch status {
        case .authorized, .provisional:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    /// 设置页状态文案。
    public static func statusCaption(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional:
            return "通知已开启"
        case .denied:
            return "请在 系统设置 → 通知 → 智余 中打开"
        case .notDetermined:
            return "系统未授权通知 · 点测试可再次请求"
        @unknown default:
            return "系统未授权通知 · 点测试可再次请求"
        }
    }

    /// 投递通知；未授权时返回 `false`。稳定 `id` 避免通知中心刷屏合并异常。
    @discardableResult
    public func post(title: String, body: String, id: String) async -> Bool {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        else {
            return false
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }
}
