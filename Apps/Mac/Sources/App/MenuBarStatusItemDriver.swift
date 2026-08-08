import AppKit

/// 对齐智额 `StatusItemLabelDriver`：用 AppKit 写 `NSStatusItem.button.image`，
/// 绕过 SwiftUI MenuBarExtra label 宿主。
///
/// 状态栏品牌图：资源 **`MenuBarIcon`**（规格对齐智额 `AppLogo`：大图 + light/dark）。
@MainActor
final class MenuBarStatusItemDriver {
    static let shared = MenuBarStatusItemDriver()

    private var statusItem: NSStatusItem?
    private var imageWipeObservation: NSKeyValueObservation?
    private var wakeObserver: NSObjectProtocol?
    private var appearanceObserver: NSObjectProtocol?
    private var lastImage: NSImage?

    /// 对齐智额：`attach` 后即可；`onAppear`/`onDisappear` 再 `reassertPresentation`。
    func attach(_ statusItem: NSStatusItem) {
        guard self.statusItem !== statusItem else {
            reassertPresentation()
            return
        }
        self.statusItem = statusItem

        // SwiftUI 开关菜单时会 wipe button.image；主线程抢回（不用 assumeIsolated）
        imageWipeObservation?.invalidate()
        imageWipeObservation = statusItem.button?.observe(\.image, options: [.new]) { [weak self] button, _ in
            Task { @MainActor in
                guard let self, let owned = self.lastImage else { return }
                if button.image !== owned {
                    button.image = owned
                }
            }
        }

        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.reassertPresentation() }
            }
        }

        if appearanceObserver == nil {
            appearanceObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name("NSApplicationDidChangeEffectiveAppearanceNotification"),
                object: NSApp,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.reassertPresentation() }
            }
        }

        reassertPresentation()
    }

    /// 对齐智额：`onAppear` / `onDisappear` 防御性重绘。
    func reassertPresentation() {
        render()
    }

    private func render() {
        guard let button = statusItem?.button else { return }

        let preferDark = NSApp.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let image = Self.brandLogoImage(preferDark: preferDark)

        if !button.title.isEmpty {
            button.title = ""
        }
        lastImage = image
        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = nil
    }

    /// 对齐智额 `brandLogoImage`：18pt、sourceOver、isTemplate=false。
    private static func brandLogoImage(preferDark: Bool) -> NSImage {
        let pointSize: CGFloat = 18
        guard let source = NSImage(named: "MenuBarIcon") else {
            return symbolImage("gauge.with.dots.needle.67percent", color: .labelColor)
        }

        let appearance = NSAppearance(named: preferDark ? .darkAqua : .aqua)
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            appearance?.performAsCurrentDrawingAppearance {
                source.draw(
                    in: rect,
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1.0,
                    respectFlipped: true,
                    hints: [.interpolation: NSImageInterpolation.high]
                )
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func symbolImage(_ name: String, color: NSColor) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: name)?
            .withSymbolConfiguration(configuration) else {
            return NSImage(size: .zero)
        }
        let size = symbol.size
        let tinted = NSImage(size: size, flipped: false) { rect in
            symbol.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.isTemplate = false
        return tinted
    }
}
