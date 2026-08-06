import SwiftUI
import Domain

/// 对齐智额：后台同步 · 额度阈值 · 登录启动 · 日志 · 更新 · 关于
struct BackgroundSystemSection: View {
    @ObservedObject var model: AppModel

    @State private var expandSync = false
    @State private var expandThreshold = false
    @State private var expandAbout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            backgroundSyncCard
            thresholdCard
            launchAtLoginCard
            logsCard
            updatesCard
            aboutCard
        }
    }

    // MARK: 后台同步

    private var backgroundSyncCard: some View {
        SettingsExpandableCard(
            icon: "arrow.triangle.2.circlepath",
            iconColors: [Color(red: 0.3, green: 0.6, blue: 0.9), Color(red: 0.2, green: 0.45, blue: 0.8)],
            title: "后台同步",
            subtitle: "自动保持数据最新 · \(model.settings.refreshInterval.label)",
            isExpanded: $expandSync
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("刷新间隔")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SBTheme.muted)

                // 第一行：关闭 · 15 · 30 · 60 分钟
                Picker("", selection: Binding(
                    get: { model.settings.refreshInterval },
                    set: { model.setRefreshInterval($0) }
                )) {
                    ForEach(RefreshInterval.row1, id: \.self) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                .pickerStyle(.segmented)

                // 第二行：4H · 12H · 24H
                Picker("", selection: Binding(
                    get: { model.settings.refreshInterval },
                    set: { model.setRefreshInterval($0) }
                )) {
                    ForEach(RefreshInterval.row2, id: \.self) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                .pickerStyle(.segmented)

                Text("后台刷新余额。选「关闭」最省电（仅手动/打开菜单时更新）。4H / 12H / 24H 适合低频查余额。")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: 额度阈值报警

    private var thresholdCard: some View {
        SettingsExpandableCard(
            icon: "bell.badge",
            iconColors: [SBTheme.accent, Color(red: 0.45, green: 0.3, blue: 0.9)],
            title: "额度阈值报警",
            subtitle: thresholdSubtitle,
            isExpanded: $expandThreshold
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("启用阈值通知")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SBTheme.text)
                        Text("余额金额或剩余百分比低于设定时，走 Mac 通知 / 邮件报警")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SBTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Toggle("", isOn: Binding(
                        get: { model.settings.alertChannels.quotaThresholdAlertsEnabled },
                        set: { model.setQuotaThresholdAlertsEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                if model.settings.alertChannels.quotaThresholdAlertsEnabled {
                    thresholdSlider(
                        title: "金额阈值 ≤",
                        value: model.settings.alertChannels.defaultAmountThreshold,
                        range: 1...200,
                        unit: "",
                        onChange: { model.setAmountThreshold($0) }
                    )
                    thresholdSlider(
                        title: "剩余百分比 ≤",
                        value: model.settings.alertChannels.defaultPercentThreshold,
                        range: 5...50,
                        unit: "%",
                        onChange: { model.setPercentThreshold($0) }
                    )
                    Text("通道开关见上方「报警通知」卡片（Mac / 邮件）。")
                        .font(.system(size: 10))
                        .foregroundStyle(SBTheme.muted)
                }
            }
        }
    }

    private var thresholdSubtitle: String {
        let ch = model.settings.alertChannels
        if !ch.quotaThresholdAlertsEnabled { return "已关闭 · 点开配置" }
        return "已开启 · 金额≤\(Int(ch.defaultAmountThreshold)) · 剩余≤\(Int(ch.defaultPercentThreshold))%"
    }

    private func thresholdSlider(
        title: String,
        value: Double,
        range: ClosedRange<Double>,
        unit: String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                Spacer()
                Text("\(Int(value.rounded()))\(unit)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(SBTheme.text)
            }
            Slider(
                value: Binding(
                    get: { value },
                    set: { onChange($0) }
                ),
                in: range,
                step: 1
            )
            .tint(SBTheme.accent)
        }
    }

    // MARK: 登录时启动

    private var launchAtLoginCard: some View {
        HStack(spacing: 10) {
            iconCircle(
                systemName: "power",
                colors: [Color(red: 0.4, green: 0.7, blue: 0.4), Color(red: 0.3, green: 0.55, blue: 0.3)]
            )
            VStack(alignment: .leading, spacing: 2) {
                Text("登录时启动")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SBTheme.text)
                Text("开机后自动在菜单栏运行")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { model.launchAtLoginEnabled },
                set: { model.setLaunchAtLogin($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .scaleEffect(0.85)
        }
        .padding(14)
        .background(cardShell)
    }

    // MARK: 日志

    private var logsCard: some View {
        HStack(spacing: 10) {
            iconCircle(
                systemName: "doc.text.fill",
                colors: [Color(red: 0.55, green: 0.5, blue: 0.65), Color(red: 0.4, green: 0.38, blue: 0.5)]
            )
            VStack(alignment: .leading, spacing: 2) {
                Text("日志")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SBTheme.text)
                Text("~/Library/Logs/SmartBalance")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                    .lineLimit(1)
            }
            Spacer()
            Button("打开") {
                model.openLogs()
            }
            .buttonStyle(SBButtonStyle(kind: .accent))
        }
        .padding(14)
        .background(cardShell)
    }

    // MARK: 软件更新

    private var updatesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                iconCircle(
                    systemName: "arrow.down.circle.fill",
                    colors: [Color(red: 0.3, green: 0.7, blue: 0.4), Color(red: 0.2, green: 0.55, blue: 0.35)]
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("软件更新")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SBTheme.text)
                    Text(model.updateMessage ?? "当前 \(model.appVersion)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(model.updateAvailable ? SBTheme.accent : SBTheme.muted)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Button {
                    model.checkForUpdates()
                } label: {
                    HStack(spacing: 4) {
                        if model.updateChecking {
                            ProgressView().controlSize(.mini).frame(width: 12, height: 12)
                        }
                        Text(model.updateChecking ? "检查中" : "检查更新")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.3, green: 0.7, blue: 0.4),
                                    Color(red: 0.2, green: 0.55, blue: 0.35),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
                }
                .buttonStyle(.plain)
                .disabled(model.updateChecking)
            }

            if model.updateAvailable, model.updateOpenURL != nil {
                Button("打开发布页") {
                    model.openUpdateURL()
                }
                .buttonStyle(SBButtonStyle(kind: .accent))
            }
        }
        .padding(14)
        .background(cardShell)
    }

    // MARK: 关于

    private var aboutCard: some View {
        SettingsExpandableCard(
            icon: "info.circle.fill",
            iconColors: [Color(red: 0.45, green: 0.5, blue: 0.6), Color(red: 0.3, green: 0.35, blue: 0.45)],
            title: "关于",
            subtitle: "\(Brand.nameCN) · v\(model.appVersion)",
            isExpanded: $expandAbout
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Brand.nameCN) · \(Brand.nameEN)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SBTheme.text)
                Text("API 直查 · 手录 · Mac 通知 · 邮件报警")
                    .font(.system(size: 11))
                    .foregroundStyle(SBTheme.muted)
                Text("v\(model.appVersion) · 本机文件 secrets.vault · 刷新时指纹解锁一次")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                Text("路径：~/Library/Application Support/SmartBalance/secrets.vault")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                    .textSelection(.enabled)
                Button {
                    model.unlockSecrets()
                } label: {
                    Label(
                        model.secretsSessionUnlocked ? "密钥已解锁" : "用指纹解锁密钥",
                        systemImage: "touchid"
                    )
                    .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(SBButtonStyle(kind: .accent))
                .disabled(model.secretsSessionUnlocked)
                Text("配置：~/Library/Application Support/SmartBalance/")
                    .font(.system(size: 10))
                    .foregroundStyle(SBTheme.muted)
                    .textSelection(.enabled)
                Text("日志：~/Library/Logs/SmartBalance/")
                    .font(.system(size: 10))
                    .foregroundStyle(SBTheme.muted)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Helpers

    private func iconCircle(systemName: String, colors: [Color]) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 28, height: 28)
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var cardShell: some View {
        RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
            .fill(SBTheme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                    .stroke(SBTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 5, y: 1)
    }
}
