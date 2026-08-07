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
                    MenuBarStatusItemDriver.shared.applyIcon()
                }
                .onDisappear {
                    MenuBarStatusItemDriver.shared.applyIcon()
                }
        } label: {
            // 占位；真正彩色 Logo 由 AppKit 写入 button.image
            Image("MenuBarIcon")
                .renderingMode(.original)
                .resizable()
                .frame(width: 18, height: 18)
                .accessibilityLabel(Brand.nameCN)
        }
        .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in
            MenuBarStatusItemDriver.shared.attach(statusItem)
            MenuBarStatusItemDriver.shared.applyIcon()
        }
        .menuBarExtraStyle(.window)
    }
}
