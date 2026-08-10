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
            // 先在 MenuBarExtra 初始 label 显示彩色 Logo；AppKit 回调绑定后仍会二次校正。
            let preferDark = NSApp.effectiveAppearance
                .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            Image(nsImage: MenuBarStatusItemDriver.makeCurrentBrandLogoImage(preferDark: preferDark))
                .renderingMode(.original)
                .interpolation(.high)
                .resizable()
                .frame(width: 18, height: 18)
                .accessibilityLabel(Brand.nameCN)
        }
        .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in
            MenuBarStatusItemDriver.shared.attach(statusItem)
        }
        .menuBarExtraStyle(.window)
    }
}
