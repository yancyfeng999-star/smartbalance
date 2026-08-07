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
        // 对齐智额：label 只做占位；真正像素由 MenuBarStatusItemDriver → MenuBarIcon
        MenuBarExtra {
            MenuRootView(model: model, runsInPinnedWindow: false)
                .onAppear {
                    PinnedBalanceWindowController.shared.bind(model: model)
                    MenuBarStatusItemDriver.shared.reassertPresentation()
                }
                .onDisappear {
                    MenuBarStatusItemDriver.shared.reassertPresentation()
                }
        } label: {
            // 对齐智额：Icon only — SF Symbol 占位，不在 label 里放真实 Logo
            Image(systemName: "gauge.with.dots.needle.67percent")
        }
        .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in
            MenuBarStatusItemDriver.shared.attach(statusItem)
        }
        .menuBarExtraStyle(.window)
    }
}
