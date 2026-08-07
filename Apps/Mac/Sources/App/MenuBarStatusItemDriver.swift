import AppKit

/// 用 AppKit 把状态栏图标画进 `NSStatusItem.button`。
/// SwiftUI `MenuBarExtra` label 对透明图易出方块底；对齐智额用 `sourceOver` + `isTemplate = false`。
@MainActor
final class MenuBarStatusItemDriver {
    static let shared = MenuBarStatusItemDriver()

    private var statusItem: NSStatusItem?
    private var imageWipeObservation: NSKeyValueObservation?
    private var ownedImage: NSImage?

    func attach(_ statusItem: NSStatusItem) {
        guard self.statusItem !== statusItem else {
            applyIcon()
            return
        }
        imageWipeObservation?.invalidate()
        self.statusItem = statusItem

        // 按内容宽度，避免 squareLength 自带「方块槽」
        statusItem.length = NSStatusItem.variableLength

        applyIcon()

        // SwiftUI 会反复清空 button.image，需抢回我们的图
        imageWipeObservation = statusItem.button?.observe(\.image, options: [.new]) { [weak self] button, _ in
            Task { @MainActor in
                guard let self, let owned = self.ownedImage else { return }
                if button.image !== owned {
                    button.image = owned
                }
            }
        }
    }

    func applyIcon(toolTip: String? = nil) {
        guard let button = statusItem?.button else { return }
        let image = Self.makeLogoImage()
        ownedImage = image
        button.image = image
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.appearsDisabled = false
        button.isBordered = false
        // 切勿 wantsLayer：layer-backed 的 status button 常整块黑/深色方底
        button.wantsLayer = false
        if let toolTip {
            button.toolTip = toolTip
        }
        statusItem?.length = NSStatusItem.variableLength
    }

    /// 从 MenuBarIcon（设计无背景 PNG）烘焙 18pt 非 template 图。
    /// 使用 `NSImage(size:flipped:)` 绘制块：画布自带透明，禁止 bitmap 残留黑底。
    static func makeLogoImage(pointSize: CGFloat = 18) -> NSImage {
        let source = NSImage(named: "MenuBarIcon") ?? NSImage(named: "AppLogo")
        guard let source else {
            let fallback = NSImage(
                systemSymbolName: "yensign.circle.fill",
                accessibilityDescription: "智余"
            ) ?? NSImage(size: NSSize(width: pointSize, height: pointSize))
            fallback.isTemplate = true
            return fallback
        }

        let size = NSSize(width: pointSize, height: pointSize)
        // 与智额 brandLogoImage 一致：block 绘制，画布默认全透明
        let image = NSImage(size: size, flipped: false) { rect in
            // 显式清成透明（防止某些系统上 bitmap 未初始化成黑不透明）
            if let cg = NSGraphicsContext.current?.cgContext {
                cg.clear(rect)
            }
            source.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
            return true
        }
        image.isTemplate = false
        return image
    }
}
