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
        } label: {
            // 占位即可：真正彩色透明 Logo 由 AppKit 写到 NSStatusItem.button
            // （SwiftUI Image 带 alpha 时常被系统衬出黑/白方块底）
            Text(Brand.nameCN)
                .frame(width: 18, height: 18)
                .opacity(0)
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
