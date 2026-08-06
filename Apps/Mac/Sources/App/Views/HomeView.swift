import SwiftUI
import Domain

struct HomeView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            modeChips

            if let banner = model.banner {
                Text(banner)
                    .font(.system(size: 11))
                    .foregroundStyle(SBTheme.warn)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            Text("大多数平台：设置里添加 API 账号。\n不能实时查的平台：配置 IMAP + 平台发件人规则，用固定邮件确认余额。\n报警：可同时开 Mac 通知与邮件报警。")
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
