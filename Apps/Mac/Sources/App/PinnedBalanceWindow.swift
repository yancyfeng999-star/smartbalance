import SwiftUI
import AppKit
import Domain

/// 固定常驻窗口：默认 380×580，主页/设置同一外框，切换不跳。
@MainActor
final class PinnedBalanceWindowController: NSObject, NSWindowDelegate {
    static let shared = PinnedBalanceWindowController()

    static let minWidth: CGFloat = 380
    static let defaultWidth: CGFloat = 380
    static let defaultHeight: CGFloat = 580
    static let minHeight: CGFloat = 420

    private var window: NSWindow?
    private var isOpening = false
    private(set) var isOpen = false
    /// 打开代数：取消/关闭后使延迟 openNow 失效
    private var openGeneration: UInt64 = 0
    /// 用户是否亲手拖过尺寸；拖过后不再强制回默认。
    private var userResized = false
    private weak var model: AppModel?

    private override init() {
        super.init()
    }

    func bind(model: AppModel) {
        self.model = model
    }

    var isPinned: Bool { isOpen || isOpening }

    func toggle() {
        if isOpen || isOpening {
            close()
        } else {
            openDeferred()
        }
    }

    func openDeferred() {
        guard let model else { return }
        if isOpen {
            positionTopRight()
            window?.orderFrontRegardless()
            return
        }
        if isOpening { return }
        isOpening = true
        openGeneration &+= 1
        let generation = openGeneration
        model.pinWindowOpen = true
        model.settings.windowPinned = true
        model.persist()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.openGeneration == generation, self.isOpening else { return }
            self.openNow(model: model, generation: generation)
        }
    }

    private func openNow(model: AppModel, generation: UInt64) {
        defer {
            if openGeneration == generation {
                isOpening = false
            }
        }
        guard openGeneration == generation else { return }

        let shell = MenuRootView(model: model, runsInPinnedWindow: true)
        let host = NSHostingView(rootView: shell)
        host.wantsLayer = true
        host.layer?.backgroundColor = SBTheme.windowNSBackground.cgColor

        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: Self.defaultWidth, height: Self.defaultHeight),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "\(Brand.nameCN) · \(Brand.nameEN)"
            win.isReleasedWhenClosed = false
            win.level = .floating
            win.hidesOnDeactivate = false
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            win.minSize = NSSize(width: Self.minWidth, height: Self.minHeight)
            win.maxSize = NSSize(width: 10_000, height: 10_000)
            win.backgroundColor = SBTheme.windowNSBackground
            win.isOpaque = true
            win.delegate = self
            window = win
        }

        window?.contentView = host
        host.autoresizingMask = [.width, .height]
        userResized = false

        // 固定默认外框；内容在壳内滚动，绝不按内容收缩
        positionTopRight(width: Self.defaultWidth, height: Self.defaultHeight)
        isOpen = true
        model.pinWindowOpen = true
        model.settings.windowPinned = true
        model.persist()
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: false)
        dismissMenuBarPopover()
    }

    /// 保证默认尺寸；切主页/设置时调用。用户拖过则只保证不小于最小值。
    func ensureDefaultSize(force: Bool = true) {
        guard isOpen, let win = window else { return }
        if userResized && !force {
            let size = win.frame.size
            if size.width < Self.minWidth || size.height < Self.minHeight {
                positionTopRight(
                    width: max(Self.minWidth, size.width),
                    height: max(Self.minHeight, size.height)
                )
            }
            return
        }
        positionTopRight(width: Self.defaultWidth, height: Self.defaultHeight)
    }

    /// 兼容旧调用
    func resize(width: CGFloat, height: CGFloat) {
        ensureDefaultSize(force: false)
        _ = width
        _ = height
    }

    /// 主题切换后刷新置顶窗背景。
    func refreshAppearance() {
        guard let win = window else { return }
        switch model?.settings.resolvedThemeMode {
        case .light:
            win.appearance = NSAppearance(named: .aqua)
        case .dark:
            win.appearance = NSAppearance(named: .darkAqua)
        case .system, .none:
            win.appearance = nil
        }
        win.backgroundColor = SBTheme.windowNSBackground
        win.contentView?.layer?.backgroundColor = SBTheme.windowNSBackground.cgColor
        win.contentView?.needsDisplay = true
    }

    func positionTopRight(width: CGFloat? = nil, height: CGFloat? = nil, preferDefaultSize: Bool = false) {
        guard let win = window, let screen = win.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var size = win.frame.size
        if let width { size.width = width }
        if let height { size.height = height }
        if preferDefaultSize {
            size.width = max(Self.minWidth, Self.defaultWidth)
            size.height = min(Self.defaultHeight, visible.height)
        }
        size.width = max(Self.minWidth, size.width)
        size.height = min(max(Self.minHeight, size.height), visible.height)
        let x = visible.maxX - size.width
        let y = visible.maxY - size.height
        // animate: false — 切 Tab 不闪
        win.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true, animate: false)
    }

    private func positionTopRight() {
        positionTopRight(preferDefaultSize: false)
    }

    func windowDidResize(_ notification: Notification) {
        guard isOpen, let win = window, win === (notification.object as? NSWindow) else { return }
        let size = win.frame.size
        // 明显偏离默认 → 记为用户拖拽
        if abs(size.width - Self.defaultWidth) > 4 || abs(size.height - Self.defaultHeight) > 4 {
            userResized = true
        }
    }

    func close() {
        openGeneration &+= 1
        isOpening = false
        isOpen = false
        if let model {
            model.pinWindowOpen = false
            model.settings.windowPinned = false
            model.persist()
        }
        window?.orderOut(nil)
        window?.contentView = NSView()
    }

    func windowWillClose(_ notification: Notification) {
        openGeneration &+= 1
        isOpen = false
        isOpening = false
        if let model {
            model.pinWindowOpen = false
            model.settings.windowPinned = false
            model.persist()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        openGeneration &+= 1
        isOpen = false
        isOpening = false
        if let model {
            model.pinWindowOpen = false
            model.settings.windowPinned = false
            model.persist()
        }
        sender.orderOut(nil)
        sender.contentView = NSView()
        return false
    }

    private func dismissMenuBarPopover() {
        // 仅收起非激活 panel（MenuBarExtra 宿主），避免误关其它窗口
        for window in NSApp.windows where window.isVisible {
            guard window !== self.window else { continue }
            if window.styleMask.contains(.nonactivatingPanel) {
                window.orderOut(nil)
            }
        }
    }
}
