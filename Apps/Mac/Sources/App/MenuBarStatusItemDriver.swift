import AppKit

/// 用 AppKit 把彩色 Logo 画进 `NSStatusItem.button`。
/// 悬停不弹 tip；标题清空避免露出「智余」文字。
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

    /// 彩色 MenuBarIcon（18pt），`isTemplate = false`。
    static func makeLogoImage(pointSize: CGFloat = 18) -> NSImage {
        let source = NSImage(named: "MenuBarIcon") ?? NSImage(named: "AppLogo")
        guard let source else {
            let fallback = NSImage(
                systemSymbolName: "yensign.circle",
                accessibilityDescription: "智余"
            ) ?? NSImage(size: NSSize(width: pointSize, height: pointSize))
            fallback.isTemplate = true
            return fallback
        }

        let size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: size, flipped: false) { rect in
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
