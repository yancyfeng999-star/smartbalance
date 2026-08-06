import SwiftUI
import Domain

@main
struct SmartBalanceApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuRootView(model: model, runsInPinnedWindow: false)
                .onAppear {
                    PinnedBalanceWindowController.shared.bind(model: model)
                }
        } label: {
            // 自定义 template 图标 + 短文案（避免 yensign.circle.fill 又丑又挤）
            HStack(spacing: 3) {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                if let title = menuBarAmountText {
                    Text(title)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
            }
            .help(menuBarHelp)
        }
        .menuBarExtraStyle(.window)
    }

    /// 状态栏只显示金额（或健康状态），不塞「智余」前缀。
    private var menuBarAmountText: String? {
        let usable = model.snapshots.filter {
            $0.status != .setup && $0.status != .error && $0.amount != nil
        }
        guard let first = usable.first else {
            // 无可用数据时仅图标
            return model.snapshots.isEmpty ? nil : "—"
        }
        // 多账号：显示最低余额（更利于盯紧报警）
        if usable.count > 1, let minSnap = usable.min(by: {
            ($0.amount ?? .greatestFiniteMagnitude) < ($1.amount ?? .greatestFiniteMagnitude)
        }) {
            return compactAmount(minSnap)
        }
        return compactAmount(first)
    }

    private func compactAmount(_ snap: BalanceSnapshot) -> String {
        guard let amount = snap.amount else { return snap.primaryText }
        // 统一紧凑：¥12 / ¥1.2k
        if amount >= 10_000 {
            return String(format: "¥%.1fw", amount / 10_000)
        }
        if amount >= 1000 {
            return String(format: "¥%.1fk", amount / 1000)
        }
        if amount >= 100 {
            return String(format: "¥%.0f", amount)
        }
        return String(format: "¥%.1f", amount)
    }

    private var menuBarHelp: String {
        let lines = model.snapshots.prefix(6).map { "\($0.displayName) \($0.primaryText)" }
        if lines.isEmpty { return "\(Brand.nameCN) · 点击打开" }
        return ([Brand.nameCN] + lines).joined(separator: "\n")
    }
}
