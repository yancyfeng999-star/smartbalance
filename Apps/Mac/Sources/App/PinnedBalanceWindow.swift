import SwiftUI
import AppKit
import Domain

/// 固定常驻窗口（对齐智额 pin）：右上角浮动，点其他应用不关闭。
@MainActor
final class PinnedBalanceWindowController: NSObject, NSWindowDelegate {
    static let shared = PinnedBalanceWindowController()

    static let minWidth: CGFloat = 380
    static let defaultWidth: CGFloat = 400
    static let defaultHeight: CGFloat = 560

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
            win.minSize = NSSize(width: Self.minWidth, height: 280)
            win.maxSize = NSSize(width: 10_000, height: 10_000)
            win.delegate = self
            window = win
        }

        let root = MenuRootView(model: model, runsInPinnedWindow: true)
            .frame(
                minWidth: Self.minWidth,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity,
                alignment: .top
            )

        let host = NSHostingView(rootView: root)
        host.autoresizingMask = [.width, .height]
        window?.contentView = host

        positionTopRight(preferDefaultSize: true)
        isOpen = true
        model.settings.windowPinned = true
        model.persist()
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: false)

        // 关闭菜单栏弹出层，避免双窗口叠着
        dismissMenuBarPopover()
    }

    func positionTopRight(preferDefaultSize: Bool = false) {
        guard let win = window, let screen = win.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var size = win.frame.size
        if preferDefaultSize {
            size.width = max(Self.minWidth, Self.defaultWidth)
            size.height = min(Self.defaultHeight, visible.height)
        }
        size.width = max(Self.minWidth, size.width)
        size.height = min(size.height, visible.height)
        let x = visible.maxX - size.width
        let y = visible.maxY - size.height
        win.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
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
                // 不关掉我们自己的 pinned 窗
                if window === self.window { continue }
                window.orderOut(nil)
            }
        }
    }
}
