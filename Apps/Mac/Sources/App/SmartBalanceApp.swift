import SwiftUI
import AppKit
import Domain
import MenuBarExtraAccess

@main
struct SmartBalanceApp: App {
    /// 对齐智额：AppKit 生命周期（关窗不退出、accessory 策略）
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    /// MenuBarExtraAccess 需要；也用于程序化开关菜单
    @State private var isMenuPresented = false

    var body: some Scene {
        MenuBarExtra {
            MenuRootView(model: model, runsInPinnedWindow: false)
                .onAppear {
                    PinnedBalanceWindowController.shared.bind(model: model)
                    MenuBarStatusItemDriver.shared.applyIcon(toolTip: menuBarHelp)
                }
                .onDisappear {
                    MenuBarStatusItemDriver.shared.applyIcon(toolTip: menuBarHelp)
                }
        } label: {
            // 占位（与智额相同思路）；真正图标由 AppKit 写入 button.image
            // 不要用带 frame 的透明 Text——宿主视图会留下矩形槽
            Image(systemName: "circle.fill")
                .opacity(0.01)
                .accessibilityLabel(Brand.nameCN)
        }
        .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in
            MenuBarStatusItemDriver.shared.attach(statusItem)
            MenuBarStatusItemDriver.shared.applyIcon(toolTip: menuBarHelp)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarHelp: String {
        let lines = model.snapshots.prefix(6).map { "\($0.displayName) \($0.primaryText)" }
        if lines.isEmpty { return "\(Brand.nameCN) · 点击打开" }
        return ([Brand.nameCN] + lines).joined(separator: "\n")
    }
}
