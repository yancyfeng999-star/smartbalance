import SwiftUI
import Domain

struct HomeView: View {
    @ObservedObject var model: AppModel
    @State private var animateIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let banner = model.banner {
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

            if model.snapshots.isEmpty {
                emptyState
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 8)
            } else {
                ForEach(Array(model.snapshots.enumerated()), id: \.element.id) { index, snap in
                    BalanceCardView(snapshot: snap, emphasized: index == 0)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 10)
                        .animation(
                            AppMotion.appear.delay(Double(index) * 0.05),
                            value: animateIn
                        )
                }
            }

            if !model.recentAlerts.isEmpty {
                Text("最近报警")
                    .font(.system(size: 12, weight: .semibold))
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
    }

    private func alertRow(_ alert: AlertEvent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(alert.title)
                    .font(.system(size: 11, weight: .semibold))
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
                .font(.system(size: 10))
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
            Text("还没有余额卡片")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(SBTheme.text)
            VStack(alignment: .leading, spacing: 4) {
                Text("· 能 API 查的：设置 → 添加 API 账号")
                Text("· 只能收邮件的：设置 → 平台邮件源 + IMAP")
                Text("· ViralTok（吉米）已内置，直接选平台粘贴 Key")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(SBTheme.muted)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                model.selectedTab = .settings
            } label: {
                Text("去设置")
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
