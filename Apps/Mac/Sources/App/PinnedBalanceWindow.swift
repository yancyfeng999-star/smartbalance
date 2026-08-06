import SwiftUI
import AppKit
import Domain

/// 固定常驻窗口（对齐智额 pin）：内容铺满，高度按内容收缩，无底部大块留白。
@MainActor
final class PinnedBalanceWindowController: NSObject, NSWindowDelegate {
    static let shared = PinnedBalanceWindowController()

    static let minWidth: CGFloat = 380
    static let defaultWidth: CGFloat = 400
    static let defaultHeight: CGFloat = 320

    private var window: NSWindow?
    private var isOpening = false
    private(set) var isOpen = false
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
        model.settings.windowPinned = true
        model.persist()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.openNow(model: model)
        }
    }

    private func openNow(model: AppModel) {
        defer { isOpening = false }

        let shell = MenuRootView(model: model, runsInPinnedWindow: true)
        let host = NSHostingView(rootView: shell)
        // 浅色底与 SwiftUI 一致，避免窗外白边
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor(srgbRed: 0.92, green: 0.93, blue: 0.96, alpha: 1).cgColor

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
            win.minSize = NSSize(width: Self.minWidth, height: 220)
            win.maxSize = NSSize(width: 10_000, height: 10_000)
            win.backgroundColor = NSColor(srgbRed: 0.92, green: 0.93, blue: 0.96, alpha: 1)
            win.isOpaque = true
            win.delegate = self
            window = win
        }

        window?.contentView = host
        host.autoresizingMask = [.width, .height]

        // 先按默认高度摆位，SwiftUI onAppear 会 resize 到内容高度
        positionTopRight(width: Self.defaultWidth, height: Self.defaultHeight)
        isOpen = true
        model.settings.windowPinned = true
        model.persist()
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: false)
        dismissMenuBarPopover()
    }

    /// 由 MenuRootView 在内容变化时调用，消除底部空白。
    func resize(width: CGFloat, height: CGFloat) {
        guard isOpen, let win = window else { return }
        let w = max(Self.minWidth, width)
        let h = max(220, min(640, height))
        positionTopRight(width: w, height: h)
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
        size.height = min(max(220, size.height), visible.height)
        let x = visible.maxX - size.width
        let y = visible.maxY - size.height
        win.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true, animate: false)
    }

    private func positionTopRight() {
        positionTopRight(preferDefaultSize: false)
    }

    func close() {
        isOpening = false
        isOpen = false
        if let model {
            model.settings.windowPinned = false
            model.persist()
        }
        window?.orderOut(nil)
        window?.contentView = NSView()
    }

    func windowWillClose(_ notification: Notification) {
        isOpen = false
        isOpening = false
        if let model {
            model.settings.windowPinned = false
            model.persist()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        isOpen = false
        isOpening = false
        if let model {
            model.settings.windowPinned = false
            model.persist()
        }
        sender.orderOut(nil)
        sender.contentView = NSView()
        return false
    }

    private func dismissMenuBarPopover() {
        for window in NSApp.windows where window.isVisible {
            if window.styleMask.contains(.nonactivatingPanel) || window.level != .normal {
                if window === self.window { continue }
                window.orderOut(nil)
            }
        }
    }
}
