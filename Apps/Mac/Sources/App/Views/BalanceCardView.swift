import SwiftUI
import Domain

struct BalanceCardView: View {
    let snapshot: BalanceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                providerBadge
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SBTheme.text)
                    HStack(spacing: 6) {
                        sourceChip
                        if let kind = snapshot.providerKind {
                            Text(kind.displayName)
                                .font(.system(size: 11))
                                .foregroundStyle(SBTheme.muted)
                        }
                    }
                }
                Spacer()
                statusPill
            }

            Text(snapshot.primaryText)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(SBTheme.statusColor(snapshot.status))

            GeometryReader { geo in
                let pct = progressPercent
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 4)
                    Capsule()
                        .fill(SBTheme.statusColor(snapshot.status))
                        .frame(width: max(4, geo.size.width * pct), height: 4)
                }
            }
            .frame(height: 4)

            if let sub = snapshot.mailSubject, !sub.isEmpty {
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundStyle(SBTheme.muted)
                    .lineLimit(1)
            }

            if let err = snapshot.errorMessage, !err.isEmpty {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(SBTheme.danger)
                    .lineLimit(2)
            } else if !snapshot.detail.isEmpty {
                Text(snapshot.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(SBTheme.muted)
                    .lineLimit(2)
            }

            Text(timeText)
                .font(.system(size: 10))
                .foregroundStyle(SBTheme.muted.opacity(0.8))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SBTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SBTheme.statusColor(snapshot.status).opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var providerBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(badgeColor.opacity(0.15))
                .frame(width: 32, height: 32)
            Text(badgeLetter)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(badgeColor)
        }
    }

    private var badgeColor: Color {
        snapshot.source == .platformEmail ? SBTheme.warn : SBTheme.accent
    }

    private var badgeLetter: String {
        if snapshot.source == .platformEmail { return "邮" }
        switch snapshot.providerKind {
        case .deepseek: return "D"
        case .newapi: return "N"
        case .openrouter: return "O"
        case .none: return "?"
        }
    }

    private var sourceChip: some View {
        Text(snapshot.sourceBadgeCN)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(badgeColor.opacity(0.12)))
    }

    private var statusPill: some View {
        Text(snapshot.status.titleCN)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(SBTheme.statusColor(snapshot.status))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(SBTheme.statusColor(snapshot.status).opacity(0.12))
            )
    }

    private var progressPercent: CGFloat {
        if let p = snapshot.remainingPercent {
            return CGFloat(max(0, min(100, p)) / 100)
        }
        if let amount = snapshot.amount {
            let cap = max(amount, 50)
            return CGFloat(max(0, min(1, amount / cap)))
        }
        return 0
    }

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f.string(from: snapshot.fetchedAt)
    }
}
