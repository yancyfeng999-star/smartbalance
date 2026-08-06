import SwiftUI
import Domain

/// 余额卡：默认折叠（名称 + 主金额 + 状态），点击展开进度与明细。
/// 字号：标题 15 / 徽章 11 / 副文 10 / 数值 12 bold / 状态 10。
struct BalanceCardView: View {
    let snapshot: BalanceSnapshot
    var emphasized: Bool = false
    /// 默认折叠，与设置页折叠卡一致。
    @State private var isExpanded = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 10 : 0) {
            headerRow
                .contentShape(Rectangle())
                .onTapGesture {
                    AppMotion.toggleExpand($isExpanded)
                }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    metersRow
                    if let err = snapshot.errorMessage, !err.isEmpty {
                        Text(err)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SBTheme.danger)
                            .lineLimit(3)
                    } else if !snapshot.detail.isEmpty {
                        Text(snapshot.detail)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SBTheme.muted)
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .transition(AppMotion.expandContent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, isExpanded ? 14 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous))
        // 展开只动卡片内部，不带动外层窗体
        .animation(AppMotion.expand, value: isExpanded)
        .onHover { hovering in
            isHovering = hovering
        }
        // 禁止内容 ideal 宽度撑破固定面板
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Header（折叠时也完整可见）

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            providerBadge

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(snapshot.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SBTheme.text)
                        .lineLimit(1)

                    if let kind = snapshot.providerKind {
                        Text(kind.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SBTheme.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(SBTheme.accent.opacity(0.12))
                            )
                            .lineLimit(1)
                    } else if snapshot.source == .platformEmail {
                        Text("平台邮件")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SBTheme.warn)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(SBTheme.warn.opacity(0.14))
                            )
                    }
                }

                // 折叠：主金额；展开：来源时间
                if isExpanded {
                    Text(sourceLine)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SBTheme.muted)
                        .lineLimit(1)
                } else {
                    Text(collapsedSubtitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(SBTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Spacer(minLength: 4)

            statusPill

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SBTheme.muted)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .animation(AppMotion.chevron, value: isExpanded)
        }
    }

    private var collapsedSubtitle: String {
        if let err = snapshot.errorMessage, !err.isEmpty, snapshot.amount == nil {
            return err
        }
        // primaryText 已带 ¥ / $ / 单位
        return snapshot.primaryText
    }

    // MARK: - Meters（展开）

    private var metersRow: some View {
        HStack(alignment: .top, spacing: 10) {
            meterColumn(
                title: "可用",
                value: snapshot.primaryText,
                progress: progressPercent,
                color: SBTheme.statusColor(snapshot.status)
            )

            if let total = snapshot.total, let used = snapshot.used {
                meterColumn(
                    title: "已用",
                    value: formatNum(used),
                    progress: total > 0 ? min(1, used / total) : 0,
                    color: SBTheme.muted
                )
                meterColumn(
                    title: "总额",
                    value: formatNum(total),
                    progress: 1,
                    color: SBTheme.accent.opacity(0.55)
                )
            } else if let pct = snapshot.remainingPercent {
                meterColumn(
                    title: "剩余",
                    value: String(format: "%.0f%%", pct),
                    progress: CGFloat(pct / 100),
                    color: SBTheme.statusColor(snapshot.status)
                )
            }
        }
    }

    private func meterColumn(title: String, value: String, progress: CGFloat, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                Spacer(minLength: 2)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(SBTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(SBTheme.progressTrack)
                        .frame(height: 5)
                    Capsule(style: .continuous)
                        .fill(color.opacity(0.88))
                        .frame(width: max(4, geo.size.width * max(0, min(1, progress))), height: 5)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusPill: some View {
        let color = SBTheme.statusColor(snapshot.status)
        return Text(SBTheme.statusLabel(snapshot.status))
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.16))
            )
    }

    private var providerBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [badgeColor.opacity(0.85), badgeColor.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 24)
            Text(badgeLetter)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var badgeColor: Color {
        switch snapshot.providerKind {
        case .deepseek: Color(red: 0.25, green: 0.55, blue: 0.95)
        case .newapi: Color(red: 0.45, green: 0.35, blue: 0.95)
        case .openrouter: Color(red: 0.55, green: 0.25, blue: 0.75)
        case .viraltok: Color(red: 0.15, green: 0.65, blue: 0.45)
        case .laozhang: Color(red: 0.95, green: 0.55, blue: 0.20)
        case .dmxapi: Color(red: 0.09, green: 0.64, blue: 0.72)
        case .kimi: Color(red: 0.20, green: 0.20, blue: 0.22)
        case .volcengine: Color(red: 0.15, green: 0.45, blue: 0.95)
        case .mimo: Color(red: 0.95, green: 0.30, blue: 0.25)
        case .minimax: Color(red: 0.55, green: 0.25, blue: 0.95)
        case .none:
            snapshot.source == .platformEmail
                ? SBTheme.warn
                : SBTheme.accent
        }
    }

    private var badgeLetter: String {
        if snapshot.source == .platformEmail, snapshot.providerKind == nil { return "邮" }
        switch snapshot.providerKind {
        case .deepseek: return "D"
        case .newapi: return "N"
        case .openrouter: return "O"
        case .viraltok: return "V"
        case .laozhang: return "张"
        case .dmxapi: return "X"
        case .kimi: return "K"
        case .volcengine: return "火"
        case .mimo: return "米"
        case .minimax: return "M"
        case .none: return "?"
        }
    }

    private var sourceLine: String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        let t = f.string(from: snapshot.fetchedAt)
        if let sub = snapshot.mailSubject, !sub.isEmpty {
            return "\(snapshot.source.titleCN) · \(sub)"
        }
        return "\(snapshot.source.titleCN) · \(t)"
    }

    private var progressPercent: CGFloat {
        if let p = snapshot.remainingPercent {
            return CGFloat(max(0, min(100, p)) / 100)
        }
        if let amount = snapshot.amount, let total = snapshot.total, total > 0 {
            return CGFloat(max(0, min(1, amount / total)))
        }
        if let amount = snapshot.amount {
            return CGFloat(max(0, min(1, amount / max(amount, 50))))
        }
        return 0
    }

    private func formatNum(_ v: Double) -> String {
        if v >= 100 { return String(format: "%.0f", v) }
        return String(format: "%.2f", v)
    }

    private var cardBackground: some View {
        // 参考图：深色玻璃卡 + 细白描边；选中/setup 用蓝边
        let strokeColor: Color = {
            if snapshot.status == .setup { return SBTheme.selectionStroke }
            if emphasized || isHovering { return SBTheme.selectionStroke }
            return SBTheme.cardStroke
        }()
        let fill: Color = {
            if snapshot.status == .setup || emphasized { return SBTheme.cardTint }
            return SBTheme.panel
        }()
        return RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: (emphasized || snapshot.status == .setup) ? 1.2 : 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 8, y: 2)
    }
}
