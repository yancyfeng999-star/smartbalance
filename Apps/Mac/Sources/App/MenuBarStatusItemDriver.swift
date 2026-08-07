import AppKit

/// 对齐智额 `StatusItemLabelDriver`：用 AppKit 写 `NSStatusItem.button.image`，
/// 绕过 SwiftUI MenuBarExtra label 宿主。
///
/// 状态栏品牌图固定用资源 **`MenuBarIcon`**（对应智额的 `AppLogo` 状态栏用法）。
@MainActor
final class MenuBarStatusItemDriver {
    static let shared = MenuBarStatusItemDriver()

    private var statusItem: NSStatusItem?
    private var imageWipeObservation: NSKeyValueObservation?
    private var lastImage: NSImage?

    /// 对齐智额：`attach` 后即可；`onAppear`/`onDisappear` 再 `reassertPresentation`。
    func attach(_ statusItem: NSStatusItem) {
        guard self.statusItem !== statusItem else {
            reassertPresentation()
            return
        }
        self.statusItem = statusItem

        // SwiftUI 开关菜单时会 wipe button.image；同 runloop 抢回（对齐智额）
        imageWipeObservation?.invalidate()
        imageWipeObservation = statusItem.button?.observe(\.image, options: [.new]) { [weak self] button, _ in
            MainActor.assumeIsolated {
                guard let self, let owned = self.lastImage else { return }
                if button.image !== owned {
                    button.image = owned
                }
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

        // 与智额相同：仅 image + imageOnly；智余额外清 title（防 Bundle 名「智余」）
        if !button.title.isEmpty {
            button.title = ""
        }
        lastImage = image
        button.image = image
        button.imagePosition = .imageOnly
        // 不设 toolTip（产品要求：悬停不弹余额摘要）
        button.toolTip = nil
    }

    /// 对齐智额 `brandLogoImage`：18pt、sourceOver、isTemplate=false。
    /// 资源名：智余用 `MenuBarIcon`（智额用 `AppLogo`）。
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

    /// 对齐智额 `symbolImage` 兜底。
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
