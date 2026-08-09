import AppKit
import Foundation

/// 用指定浏览器打开链接。默认优先 Google Chrome，未安装则回退系统默认浏览器。
public enum BrowserLauncher: Sendable {
    public static let chromeBundleId = "com.google.Chrome"

    /// 优先 Chrome 打开；失败或未装 Chrome 时用系统默认。
    @MainActor
    public static func open(_ url: URL, preferChrome: Bool = true) {
        guard preferChrome,
              let chrome = NSWorkspace.shared.urlForApplication(withBundleIdentifier: chromeBundleId)
        else {
            NSWorkspace.shared.open(url)
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: chrome, configuration: config) { _, error in
            if error != nil {
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
