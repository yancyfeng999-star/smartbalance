import SwiftUI
import Domain

/// 智额风格余额卡：图标 + 名称徽章 + 状态胶囊 + 金额/进度。
struct BalanceCardView: View {
    let snapshot: BalanceSnapshot
    var emphasized: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            metersRow
            if let err = snapshot.errorMessage, !err.isEmpty {
                Text(err)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SBTheme.danger)
                    .lineLimit(2)
            } else if !snapshot.detail.isEmpty {
                Text(snapshot.detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 10) {
            providerBadge

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(snapshot.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(SBTheme.text)
                        .lineLimit(1)

                    if let kind = snapshot.providerKind {
                        Text(kind.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SBTheme.accent)
                            .padding(.horizontal, 8)
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
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(SBTheme.warn.opacity(0.14))
                            )
                    }
                }

                Text(sourceLine)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            statusPill
        }
    }

    private var metersRow: some View {
        HStack(alignment: .top, spacing: 14) {
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
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                Spacer(minLength: 2)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(SBTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(SBTheme.progressTrack)
                        .frame(height: 5)
                    Capsule()
                        .fill(color)
                        .frame(width: max(4, geo.size.width * max(0, min(1, progress))), height: 5)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusPill: some View {
        let label: String = {
            if snapshot.status == .error || snapshot.status == .setup {
                return SBTheme.statusLabel(snapshot.status)
            }
            // 刷新中由外层处理；这里 healthy → 充足
            return SBTheme.statusLabel(snapshot.status)
        }()
        let color = SBTheme.statusColor(snapshot.status)
        return Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.14))
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
                .frame(width: 30, height: 30)
            Text(badgeLetter)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var badgeColor: Color {
        switch snapshot.providerKind {
        case .deepseek: Color(red: 0.25, green: 0.55, blue: 0.95)
        case .newapi: Color(red: 0.45, green: 0.35, blue: 0.95)
        case .openrouter: Color(red: 0.55, green: 0.25, blue: 0.75)
        case .viraltok: Color(red: 0.15, green: 0.65, blue: 0.45)
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
        RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
            .fill(emphasized ? SBTheme.cardTint : SBTheme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                    .strokeBorder(
                        emphasized ? SBTheme.accent.opacity(0.35) : SBTheme.cardStroke,
                        lineWidth: emphasized ? 1.2 : 1
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }
}
