import Foundation
import UserNotifications
import AppKit

/// macOS 系统通知。
public final class MacNotificationService: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    public static let shared = MacNotificationService()

    private let center = UNUserNotificationCenter.current()
    private var didInstallDelegate = false

    public override init() {
        super.init()
    }

    /// 菜单栏 App 必须设置 delegate，否则前台时通知可能不展示。
    @MainActor
    public func installDelegateIfNeeded() {
        guard !didInstallDelegate else { return }
        center.delegate = self
        didInstallDelegate = true
    }

    @MainActor
    public func requestAuthorizationIfNeeded() async -> Bool {
        installDelegateIfNeeded()
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
                AppLog.error("Notification auth error: \(error.localizedDescription)")
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

    /// 投递通知。使用短延迟 trigger，菜单栏 App 上更可靠。
    @discardableResult
    public func post(title: String, body: String, id: String) async -> Bool {
        await MainActor.run { installDelegateIfNeeded() }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        else {
            AppLog.error("Notification not authorized: \(settings.authorizationStatus.rawValue)")
            return false
        }

        // 对齐智额 SystemAlertSender：title/body/sound，图标一律走包内 AppIcon
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        // 智额用 nil trigger；菜单栏 agent 上偶发不弹，保留极短延迟更稳
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.15, repeats: false)
        let request = UNNotificationRequest(
            identifier: id + "-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
            AppLog.info("Notification scheduled: \(title)")
            return true
        } catch {
            AppLog.error("Notification add failed: \(error.localizedDescription)")
            return false
        }
    }

    /// 每日固定时刻提醒手录余额（MiMo / MiniMax 等）。
    /// - Parameters:
    ///   - hour/minute: 本地时区
    ///   - names: 需要提醒的账号名；空则取消定时
    public func scheduleDailyManualBalanceReminder(
        hour: Int = 10,
        minute: Int = 0,
        names: [String]
    ) async {
        await MainActor.run { installDelegateIfNeeded() }
        let id = "smartbalance.daily-manual-balance"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard !names.isEmpty else {
            AppLog.info("Daily manual reminder cleared")
            return
        }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        else {
            AppLog.error("Cannot schedule daily reminder: notifications not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "智余 · 录入余额"
        let list = names.joined(separator: "、")
        content.body = "请打开 \(list) 后台核对余额，并在智余设置中更新手录金额。"
        content.sound = .default
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        var dc = DateComponents()
        dc.hour = hour
        dc.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await center.add(request)
            AppLog.info("Daily manual reminder at \(hour):\(String(format: "%02d", minute)) · \(list)")
        } catch {
            AppLog.error("Daily reminder schedule failed: \(error.localizedDescription)")
        }
    }

    // 前台也弹横幅（对齐用户「测试有反应」预期）
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
