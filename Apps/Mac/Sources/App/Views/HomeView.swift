import SwiftUI
import Domain

struct HomeView: View {
    @ObservedObject var model: AppModel
    @State private var animateIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.isReorderMode {
                reorderBanner
            }

            if let banner = model.banner, !model.isReorderMode {
                HStack(alignment: .top, spacing: 8) {
                    Text(banner)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SBTheme.warn)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        model.banner = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(SBTheme.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(SBTheme.warn.opacity(0.12))
                )
            }

            // 有配置账号就始终走卡片；仅「真的一个账号都没有」才显示引导
            if model.settings.enabledAccounts.isEmpty && model.snapshots.isEmpty {
                emptyState
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 8)
            } else {
                ForEach(Array(model.snapshots.enumerated()), id: \.element.id) { index, snap in
                    HStack(alignment: .center, spacing: 6) {
                        BalanceCardView(
                            snapshot: snap,
                            emphasized: index == 0 && !model.isReorderMode,
                            isReorderMode: model.isReorderMode,
                            onLongPress: {
                                model.enterReorderMode()
                            }
                        )
                        .frame(maxWidth: .infinity)

                        if model.isReorderMode {
                            reorderControls(accountId: snap.accountId, index: index)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 10)
                    .animation(
                        AppMotion.appear.delay(Double(index) * 0.05),
                        value: animateIn
                    )
                }
                .animation(AppMotion.selection, value: model.isReorderMode)
                .animation(AppMotion.selection, value: model.snapshots.map(\.accountId))
            }

            if !model.recentAlerts.isEmpty, !model.isReorderMode {
                Text("最近报警")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SBTheme.muted)
                    .padding(.top, 2)
                ForEach(model.recentAlerts.prefix(2)) { alert in
                    alertRow(alert)
                }
            }
        }
        .onAppear {
            withAnimation(AppMotion.appear) {
                animateIn = true
            }
        }
        .onChange(of: model.snapshots.count) { _, _ in
            // 刷新后重新轻入
            animateIn = false
            withAnimation(AppMotion.appear) {
                animateIn = true
            }
        }
        .onChange(of: model.settings.accounts.count) { _, _ in
            // 账号列表变了且卡为空时，Home 侧也会重新出现
            if model.snapshots.isEmpty, !model.settings.enabledAccounts.isEmpty {
                animateIn = false
                withAnimation(AppMotion.appear) {
                    animateIn = true
                }
            }
        }
    }

    // MARK: - Reorder（对齐智额）

    private var reorderBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SBTheme.accent)
            Text("排序模式 · 用右侧箭头调整顺序")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
            Spacer(minLength: 4)
            Button {
                model.exitReorderMode()
            } label: {
                Text("完成")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(SBTheme.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SBTheme.accent.opacity(0.08))
        )
    }

    private func reorderControls(accountId: UUID, index: Int) -> some View {
        let last = model.snapshots.count - 1
        return VStack(spacing: 2) {
            Button {
                model.moveAccount(id: accountId, up: true)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 26, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(index == 0)
            .foregroundStyle(index == 0 ? SBTheme.muted.opacity(0.35) : SBTheme.text)

            Button {
                model.moveAccount(id: accountId, up: false)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 26, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(index >= last)
            .foregroundStyle(index >= last ? SBTheme.muted.opacity(0.35) : SBTheme.text)
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SBTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(SBTheme.stroke, lineWidth: 0.8)
                )
        )
    }

    private func alertRow(_ alert: AlertEvent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(alert.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SBTheme.text)
                    .lineLimit(1)
                Spacer()
                if alert.notified {
                    Text("通知")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(SBTheme.ok)
                }
                if alert.emailed {
                    Text("邮件")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(SBTheme.accent)
                }
            }
            Text(alert.message)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .lineLimit(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SBTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(SBTheme.stroke, lineWidth: 1)
                )
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("智余 · 监控 API 余额")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SBTheme.text)
            Text("在菜单栏查看各平台 API / Token 还剩多少钱。")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                Text("1. 设置 → API 账号 → 添加平台")
                Text("2. 贴 Key 自动查，或选手录金额（MiMo / MiniMax / API Nebula）")
                Text("3. 偏低时：Mac 通知 / 邮件报警")
                Text("4. 长按卡片可调整顺序")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(SBTheme.muted)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                model.selectedTab = .settings
            } label: {
                Text("去添加账号")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(SBTheme.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                .fill(SBTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                        .stroke(SBTheme.cardStroke, lineWidth: 1)
                )
        )
    }
}
