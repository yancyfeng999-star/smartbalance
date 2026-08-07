import AppKit

/// 用 AppKit 把状态栏图标画进 `NSStatusItem.button`。
/// 通用单色 Template：随菜单栏浅/深自动变黑/白，与系统其它状态栏图标一致。
@MainActor
final class MenuBarStatusItemDriver {
    static let shared = MenuBarStatusItemDriver()

    private var statusItem: NSStatusItem?
    private var imageWipeObservation: NSKeyValueObservation?
    private var titleWipeObservation: NSKeyValueObservation?
    private var ownedImage: NSImage?

    func attach(_ statusItem: NSStatusItem) {
        guard self.statusItem !== statusItem else {
            applyIcon()
            return
        }
        imageWipeObservation?.invalidate()
        titleWipeObservation?.invalidate()
        self.statusItem = statusItem

        statusItem.length = NSStatusItem.variableLength

        applyIcon()

        // SwiftUI 会反复清空 button.image / 塞回标题，需抢回「仅图标」
        imageWipeObservation = statusItem.button?.observe(\.image, options: [.new]) { [weak self] button, _ in
            Task { @MainActor in
                guard let self, let owned = self.ownedImage else { return }
                if button.image !== owned {
                    button.image = owned
                }
                if !button.title.isEmpty {
                    button.title = ""
                }
                button.imagePosition = .imageOnly
            }
        }
        titleWipeObservation = statusItem.button?.observe(\.title, options: [.new]) { [weak self] button, _ in
            Task { @MainActor in
                guard self != nil else { return }
                if !button.title.isEmpty {
                    button.title = ""
                }
                button.imagePosition = .imageOnly
            }
        }
    }

    func applyIcon(toolTip: String? = nil) {
        guard let button = statusItem?.button else { return }
        let image = Self.makeLogoImage()
        ownedImage = image
        button.title = ""
        button.image = image
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.appearsDisabled = false
        button.isBordered = false
        button.wantsLayer = false
        button.setAccessibilityLabel("智余")
        button.setAccessibilityTitle("智余")
        if let toolTip {
            button.toolTip = toolTip
        }
        statusItem?.length = NSStatusItem.variableLength
    }

    /// 状态栏通用 Template 图标（18pt）：系统按菜单栏着色。
    static func makeLogoImage(pointSize: CGFloat = 18) -> NSImage {
        if let source = NSImage(named: "MenuBarIcon") {
            // 拷贝后设尺寸 + template，避免改到 catalog 缓存
            let image = source.copy() as? NSImage ?? source
            image.size = NSSize(width: pointSize, height: pointSize)
            image.isTemplate = true
            return image
        }
        let fallback = NSImage(
            systemSymbolName: "yensign.circle",
            accessibilityDescription: "智余"
        ) ?? NSImage(size: NSSize(width: pointSize, height: pointSize))
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let symbol = fallback.withSymbolConfiguration(config) ?? fallback
        symbol.isTemplate = true
        return symbol
    }
}
