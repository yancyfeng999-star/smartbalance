import AppKit
import Infrastructure

/// 对齐智额：菜单栏 agent 关闭窗口不退出进程。
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Explicit quit only. Closing the menu window does not reach here.
        stopWorkspaceLifecycleObservers()
        CrashRecoveryStore.shared.markCleanQuit()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 与智额一致：强制 accessory，避免测试包覆盖 Info.plist 后出现 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        // 去掉 Finder 自定义 Icon（旧版 setIcon 残留会锁通知中心旧图；智额从不写自定义 Icon）
        Self.stripCustomFinderIconIfNeeded()
        startWorkspaceLifecycleObservers()
    }

    private func startWorkspaceLifecycleObservers() {
        let center = NSWorkspace.shared.notificationCenter
        if sleepObserver == nil {
            sleepObserver = center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    AppLifecycleCenter.shared.noteWillSleep()
                }
            }
        }
        if wakeObserver == nil {
            wakeObserver = center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    AppLifecycleCenter.shared.noteDidWake()
                }
            }
        }
    }

    private func stopWorkspaceLifecycleObservers() {
        let center = NSWorkspace.shared.notificationCenter
        if let sleepObserver {
            center.removeObserver(sleepObserver)
            self.sleepObserver = nil
        }
        if let wakeObserver {
            center.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    /// 只使用包内 AppIcon.icns / asset catalog，不写自定义 Icon。
    private static func stripCustomFinderIconIfNeeded() {
        let appPath = Bundle.main.bundlePath
        let iconFile = (appPath as NSString).appendingPathComponent("Icon\r")
        try? FileManager.default.removeItem(atPath: iconFile)
        let iconAlt = (appPath as NSString).appendingPathComponent("Icon")
        try? FileManager.default.removeItem(atPath: iconAlt)
        // nil = 清除自定义图标，回退到 bundle 内白底 AppIcon
        _ = NSWorkspace.shared.setIcon(nil, forFile: appPath, options: [])
    }
}
