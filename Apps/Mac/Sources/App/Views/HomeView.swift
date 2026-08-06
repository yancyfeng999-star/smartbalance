import SwiftUI
import Domain

struct HomeView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            modeChips

            if let banner = model.banner {
                HStack(alignment: .top, spacing: 8) {
                    Text(banner)
                        .font(.system(size: 11))
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
                    .help("关闭")
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(SBTheme.warn.opacity(0.12))
                )
            }

            if model.snapshots.isEmpty {
                emptyState
            } else {
                ForEach(model.snapshots) { snap in
                    BalanceCardView(snapshot: snap)
                }
            }

            if !model.recentAlerts.isEmpty {
                Text("最近报警")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SBTheme.muted)
                    .padding(.top, 4)
                ForEach(model.recentAlerts.prefix(3)) { alert in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(alert.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(SBTheme.text)
                                .lineLimit(1)
                            Spacer()
                            if alert.notified {
                                Text("通知")
                                    .font(.system(size: 10))
                                    .foregroundStyle(SBTheme.ok)
                            }
                            if alert.emailed {
                                Text("邮件")
                                    .font(.system(size: 10))
                                    .foregroundStyle(SBTheme.accent)
                            }
                        }
                        Text(alert.message)
                            .font(.system(size: 10))
                            .foregroundStyle(SBTheme.muted)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(SBTheme.panel)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(SBTheme.stroke, lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    private var modeChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                modeChip(title: "API 查询", on: model.settings.apiQueryEnabled)
                modeChip(title: "平台邮件", on: model.settings.platformMailEnabled && model.settings.inboundMailbox.enabled)
            }
            HStack(spacing: 8) {
                modeChip(title: "Mac 通知", on: model.settings.alertChannels.macNotificationEnabled)
                modeChip(
                    title: "邮件报警",
                    on: model.settings.alertChannels.outboundEmailEnabled && model.settings.email.enabled
                )
            }
        }
    }

    private func modeChip(title: String, on: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(on ? SBTheme.ok : SBTheme.muted.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(on ? SBTheme.text : SBTheme.muted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(on ? SBTheme.ok.opacity(0.12) : Color.white.opacity(0.04))
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("还没有余额卡片")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SBTheme.text)
            VStack(alignment: .leading, spacing: 4) {
                Text("· 能 API 查的：设置 → 添加 API 账号")
                Text("· 只能收邮件的：设置 → 平台邮件源 + IMAP")
                Text("· 报警：打开 Mac 通知和/或邮件报警")
            }
            .font(.system(size: 12))
            .foregroundStyle(SBTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
            Button("去设置") {
                model.selectedTab = .settings
            }
            .buttonStyle(SBButtonStyle(kind: .accent))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(SBTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(SBTheme.stroke, lineWidth: 1)
                )
        )
    }
}
