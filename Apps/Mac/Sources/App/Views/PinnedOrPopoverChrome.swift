import SwiftUI
import AppKit

// MARK: - Fixed panel chrome

/// Popover：固定 380×580，主页 ↔ 设置绝不改尺寸。
/// 置顶窗：铺满宿主，由 NSWindow 控制外框，内容只滚动。
struct PinnedOrPopoverChrome: ViewModifier {
    let runsInPinnedWindow: Bool

    private var panelW: CGFloat { SBTheme.panelWidth }
    private var panelH: CGFloat { SBTheme.panelHeight() }

    func body(content: Content) -> some View {
        if runsInPinnedWindow {
            content
                .frame(
                    minWidth: panelW,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: .infinity,
                    alignment: .top
                )
        } else {
            content
                .frame(width: panelW, height: panelH, alignment: .top)
                .frame(
                    minWidth: panelW, idealWidth: panelW, maxWidth: panelW,
                    minHeight: panelH, idealHeight: panelH, maxHeight: panelH,
                    alignment: .top
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipped()
                // MenuBarExtra 会跟 ideal size 走；再钉一次 AppKit 尺寸
                .background(PanelSizeLock(width: panelW, height: panelH))
        }
    }
}

// MARK: - AppKit size lock

/// 把 MenuBarExtra `.window` 宿主 NSWindow 的 contentSize 锁死，
/// 避免切 Tab / 展开卡片时系统按内容重算导致「跳一下」。
struct PanelSizeLock: NSViewRepresentable {
    let width: CGFloat
    let height: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = SizeLockView()
        view.targetSize = NSSize(width: width, height: height)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? SizeLockView else { return }
        view.targetSize = NSSize(width: width, height: height)
        view.applyLockIfNeeded()
    }

    private final class SizeLockView: NSView {
        var targetSize: NSSize = .zero
        private var lastApplied: NSSize = .zero

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyLockIfNeeded()
        }

        override func layout() {
            super.layout()
            applyLockIfNeeded()
        }

        func applyLockIfNeeded() {
            guard let window, targetSize.width > 0, targetSize.height > 0 else { return }
            // 跳过置顶主窗（有标题栏）
            if window.styleMask.contains(.titled) { return }

            let content = window.contentView?.bounds.size ?? .zero
            let needW = abs(content.width - targetSize.width) > 0.5
            let needH = abs(content.height - targetSize.height) > 0.5
            let already = abs(lastApplied.width - targetSize.width) < 0.5
                && abs(lastApplied.height - targetSize.height) < 0.5
            if already && !needW && !needH { return }

            // 禁止系统再按内容自动收缩
            window.contentMinSize = targetSize
            window.contentMaxSize = targetSize
            if needW || needH {
                window.setContentSize(targetSize)
            }
            lastApplied = targetSize
        }
    }
}
