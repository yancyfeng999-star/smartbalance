import SwiftUI
import Domain

@main
struct SmartBalanceApp: App {
    /// 对齐智额：AppKit 生命周期（关窗不退出、accessory 策略）
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuRootView(model: model, runsInPinnedWindow: false)
                .onAppear {
                    PinnedBalanceWindowController.shared.bind(model: model)
                }
        } label: {
            // 真透明彩色 Logo；不要 padding/背景容器，否则菜单栏会显方块底
            Image("MenuBarIcon")
                .renderingMode(.original)
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .help(menuBarHelp)
                .accessibilityLabel(Brand.nameCN)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarHelp: String {
        let lines = model.snapshots.prefix(6).map { "\($0.displayName) \($0.primaryText)" }
        if lines.isEmpty { return "\(Brand.nameCN) · 点击打开" }
        return ([Brand.nameCN] + lines).joined(separator: "\n")
    }
}
