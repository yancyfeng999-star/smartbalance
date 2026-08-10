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
    private var startupTransparencyTask: Task<Void, Never>?

    /// 在 MenuBarExtraAccess 回调之前处理状态栏宿主窗口，避免启动加载阶段出现不透明背景。
    func startStartupTransparencyBootstrap() {
        guard startupTransparencyTask == nil else { return }

        startupTransparencyTask = Task { @MainActor [weak self] in
            defer { self?.startupTransparencyTask = nil }

            // MenuBarExtraAccess 本身会等待状态栏窗口出现；这里保持略长的窗口，
            // 覆盖它的发现延迟，同时避免永久轮询。
            for _ in 0..<60 {
                guard !Task.isCancelled, let self else { return }
                self.configureDiscoveredHostWindows()

                if self.statusItem?.button?.window != nil {
                    return
                }

                try? await Task.sleep(nanoseconds: 50_000_000)
            }

            self?.configureDiscoveredHostWindows()
        }
    }

    /// 对齐智额：`attach` 后即可；`onAppear`/`onDisappear` 再 `reassertPresentation`。
    func attach(_ statusItem: NSStatusItem) {
        guard self.statusItem !== statusItem else {
            if statusItem.button?.window == nil {
                startStartupTransparencyBootstrap()
            }
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

        if statusItem.button?.window == nil {
            startStartupTransparencyBootstrap()
        }
        reassertPresentation()
    }

    /// 对齐智额：`onAppear` / `onDisappear` 防御性重绘。
    func reassertPresentation() {
        render()
    }

    /// 用于 `MenuBarExtra` 初始 label 的彩色图像；状态项尚未被回调绑定前也能显示品牌图。
    static func makeCurrentBrandLogoImage(preferDark: Bool) -> NSImage {
        guard let source = NSImage(named: "MenuBarIcon") else {
            return symbolImage("gauge.with.dots.needle.67percent", color: .labelColor)
        }
        return makeCurrentBrandLogoImage(from: source, preferDark: preferDark)
    }

    static func makeCurrentBrandLogoImage(from source: NSImage, preferDark: Bool) -> NSImage {
        makeAlphaBackedColorImage(
            from: source,
            pointSize: 18,
            appearance: NSAppearance(named: preferDark ? .darkAqua : .aqua)
        )
    }

    private func render() {
        guard let button = statusItem?.button else { return }

        // macOS 26's MenuBarExtraAccess host is an NSStatusBarWindow. Its
        // default opaque content view paints a white slot behind non-template
        // images even when the status button and image are transparent.
        if let window = button.window {
            Self.configureHostWindowForTransparency(window)
        }

        let preferDark = NSApp.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let image = Self.brandLogoImage(preferDark: preferDark)

        if !button.title.isEmpty {
            button.title = ""
        }
        lastImage = image
        button.image = image
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.isBordered = false
        button.isTransparent = true
        button.wantsLayer = false
        button.toolTip = nil
    }

    /// 清除 macOS 状态栏宿主窗口的默认底色，供启动期扫描和已绑定状态项共同使用。
    static func configureHostWindowForTransparency(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    private func configureDiscoveredHostWindows() {
        for window in NSApp.windows where window.className.contains("NSStatusBarWindow") {
            Self.configureHostWindowForTransparency(window)
        }
    }

    /// 对齐智额 `brandLogoImage`：18pt、带 Alpha 的 bitmap、sourceOver、isTemplate=false。
    private static func brandLogoImage(preferDark: Bool) -> NSImage {
        let pointSize: CGFloat = 18
        guard let source = NSImage(named: "MenuBarIcon") else {
            return symbolImage("gauge.with.dots.needle.67percent", color: .labelColor)
        }

        let appearance = NSAppearance(named: preferDark ? .darkAqua : .aqua)
        return makeAlphaBackedColorImage(from: source, pointSize: pointSize, appearance: appearance)
    }

    static func makeAlphaBackedColorImage(
        from source: NSImage,
        pointSize: CGFloat = 18,
        appearance: NSAppearance? = nil
    ) -> NSImage {
        let imageSize = NSSize(width: pointSize, height: pointSize)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let pixels = max(1, Int((pointSize * scale).rounded()))
        guard let bitmapRepresentation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return symbolImage("gauge.with.dots.needle.67percent", color: .labelColor)
        }
        bitmapRepresentation.size = imageSize

        NSGraphicsContext.saveGraphicsState()
        if let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmapRepresentation) {
            NSGraphicsContext.current = graphicsContext
            graphicsContext.imageInterpolation = .high
            graphicsContext.cgContext.clear(
                CGRect(x: 0, y: 0, width: CGFloat(pixels), height: CGFloat(pixels))
            )
            appearance?.performAsCurrentDrawingAppearance {
                source.draw(
                    in: NSRect(origin: .zero, size: imageSize),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1.0,
                    respectFlipped: true,
                    hints: [.interpolation: NSImageInterpolation.high]
                )
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: imageSize)
        image.addRepresentation(bitmapRepresentation)
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
