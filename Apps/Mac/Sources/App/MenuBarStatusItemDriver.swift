import AppKit

/// 状态栏仅用系统 SF Symbol（Template）。
/// 自定义 PNG 无论彩色/单色，在 MenuBarExtra 上仍易被系统衬出方底；SF Symbol 与其它状态栏图标一致。
@MainActor
final class MenuBarStatusItemDriver {
    static let shared = MenuBarStatusItemDriver()

    /// 余额场景：日元/圆符号圆标，单色 Template
    static let symbolName = "yensign.circle"

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

        imageWipeObservation = statusItem.button?.observe(\.image, options: [.new]) { [weak self] button, _ in
            Task { @MainActor in
                guard let self, let owned = self.ownedImage else { return }
                if button.image !== owned {
                    button.image = owned
                }
                Self.stripTitle(button)
            }
        }
        titleWipeObservation = statusItem.button?.observe(\.title, options: [.new]) { [weak self] button, _ in
            Task { @MainActor in
                guard self != nil else { return }
                Self.stripTitle(button)
            }
        }
    }

    func applyIcon() {
        guard let button = statusItem?.button else { return }
        let image = Self.makeLogoImage()
        ownedImage = image
        Self.stripTitle(button)
        button.image = image
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.appearsDisabled = false
        button.isBordered = false
        button.wantsLayer = false
        // 不设 toolTip：悬停不弹余额摘要
        button.toolTip = nil
        button.setAccessibilityLabel("智余")
        button.setAccessibilityTitle("智余")
        statusItem?.length = NSStatusItem.variableLength
    }

    private static func stripTitle(_ button: NSStatusBarButton) {
        if !button.title.isEmpty {
            button.title = ""
        }
        button.imagePosition = .imageOnly
    }

    /// 系统符号 Template：浅色栏黑、深色栏白，无自定义 PNG 方底问题。
    static func makeLogoImage(pointSize: CGFloat = 15) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: "智余")?
            .withSymbolConfiguration(config) {
            let image = symbol.copy() as? NSImage ?? symbol
            image.isTemplate = true
            return image
        }
        // 极旧系统兜底
        let empty = NSImage(size: NSSize(width: pointSize, height: pointSize))
        empty.isTemplate = true
        return empty
    }
}
