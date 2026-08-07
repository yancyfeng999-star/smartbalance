import SwiftUI
import Domain

/// 后台同步 · 额度阈值 · 登录启动 · 日志 · 更新 · 关于
struct BackgroundSystemSection: View {
    @ObservedObject var model: AppModel

    @State private var expandSync = false
    @State private var expandThreshold = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            backgroundSyncCard
            thresholdCard
            launchAtLoginCard
            dataBackupCard
            logsCard
            updatesCard
            aboutLine
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
                    Text("人民币金额分档（吉米/老张已折算 ¥）")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SBTheme.muted)
                    thresholdSlider(
                        title: "偏低 ≤ ¥",
                        value: model.settings.alertChannels.warningAmount,
                        range: 30...2000,
                        unit: "",
                        onChange: { model.setWarningAmount($0) }
                    )
                    thresholdSlider(
                        title: "不足 ≤ ¥",
                        value: model.settings.alertChannels.midAmount,
                        range: 10...500,
                        unit: "",
                        onChange: { model.setMidAmount($0) }
                    )
                    thresholdSlider(
                        title: "危急 ≤ ¥",
                        value: model.settings.alertChannels.criticalAmount,
                        range: 1...200,
                        unit: "",
                        onChange: { model.setCriticalAmount($0) }
                    )
                    Text("有额度百分比时额外参考")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SBTheme.muted)
                        .padding(.top, 4)
                    thresholdSlider(
                        title: "偏低 ≤",
                        value: model.settings.alertChannels.warningPercent,
                        range: 5...80,
                        unit: "%",
                        onChange: { model.setWarningPercent($0) }
                    )
                    thresholdSlider(
                        title: "不足 ≤",
                        value: model.settings.alertChannels.midPercent,
                        range: 3...50,
                        unit: "%",
                        onChange: { model.setMidPercent($0) }
                    )
                    thresholdSlider(
                        title: "危急 ≤",
                        value: model.settings.alertChannels.criticalPercent,
                        range: 1...40,
                        unit: "%",
                        onChange: { model.setCriticalPercent($0) }
                    )
                    Text("档位：充足 → 偏低(≤100) → 不足(≤50) → 危急(≤20) → 耗尽(≤0)。")
                        .font(.system(size: 10))
                        .foregroundStyle(SBTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var thresholdSubtitle: String {
        let ch = model.settings.alertChannels
        if !ch.quotaThresholdAlertsEnabled { return "已关闭 · 点开配置" }
        return "偏低¥\(Int(ch.warningAmount)) · 不足¥\(Int(ch.midAmount)) · 危急¥\(Int(ch.criticalAmount))"
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

    // MARK: 数据导出 / 导入

    private var dataBackupCard: some View {
        HStack(spacing: 10) {
            iconCircle(
                systemName: "externaldrive.fill.badge.timemachine",
                colors: [Color(red: 0.35, green: 0.55, blue: 0.85), Color(red: 0.25, green: 0.4, blue: 0.75)]
            )
            Text("数据备份")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(SBTheme.text)
            Spacer(minLength: 8)
            Button("导出") {
                model.exportDataBackup()
            }
            .buttonStyle(SBButtonStyle(kind: .accent))
            Button("导入") {
                model.importDataBackup()
            }
            .buttonStyle(SBButtonStyle(kind: .normal))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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

            if let progress = model.updateDownloadProgress {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress, total: 1)
                        .progressViewStyle(.linear)
                        .tint(Color(red: 0.3, green: 0.7, blue: 0.4))
                    Text("下载 \(Int((progress * 100).rounded()))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SBTheme.muted)
                        .monospacedDigit()
                }
            }

            if model.updateAvailable, model.updateOpenURL != nil, model.updateDownloadProgress == nil {
                Button("打开下载 / 发布页") {
                    model.openUpdateURL()
                }
                .buttonStyle(SBButtonStyle(kind: .accent))
            }
        }
        .padding(14)
        .background(cardShell)
    }

    // MARK: 关于（固定卡片，不折叠）

    private var aboutLine: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image("AppLogo")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("关于")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SBTheme.text)
                    Text(model.appVersion)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SBTheme.muted)
                }
                Spacer(minLength: 0)
            }
            Text(Brand.aboutLine)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardShell)
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
