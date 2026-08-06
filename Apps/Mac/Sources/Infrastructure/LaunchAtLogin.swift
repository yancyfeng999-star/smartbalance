import Foundation
import ServiceManagement

/// 登录时启动（SMAppService，对齐智额）。
public enum LaunchAtLogin {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            AppLog.info("Launch at login → \(enabled)")
            return true
        } catch {
            AppLog.error("Launch at login failed: \(error.localizedDescription)")
            return false
        }
    }
}
