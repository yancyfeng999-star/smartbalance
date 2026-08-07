import AppKit

/// 用 AppKit 把状态栏图标画进 `NSStatusItem.button`。
/// SwiftUI `MenuBarExtra` 的 label 对带透明 PNG 常会衬出黑/白方块底；
/// 对齐智额：`isTemplate = false` + `sourceOver` 绘制。
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
        button.appearsDisabled = false
        if let toolTip {
            button.toolTip = toolTip
        }
        // 避免 layer 默认不透明黑底
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
    }

    /// 从资源里的 MenuBarIcon（设计 PNG 缩放）烘焙 18pt 非 template 图。
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

        // 按屏幕 scale 烘焙，避免 1x 糊边被系统再衬底
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let px = max(1, Int((pointSize * scale).rounded()))
        let pixelSize = NSSize(width: px, height: px)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: px,
            pixelsHigh: px,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = NSSize(width: pointSize, height: pointSize)

        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            ctx.imageInterpolation = .high
            // 透明底：不 fill 任何颜色
            let rect = NSRect(origin: .zero, size: NSSize(width: pointSize, height: pointSize))
            source.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        image.addRepresentation(rep)
        image.isTemplate = false
        return image
    }
}
