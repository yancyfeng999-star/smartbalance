import SwiftUI
import Domain

/// 余额卡：默认折叠（名称 + 主金额 + 状态），点击展开进度与明细。
/// 交互对齐智额：不用 Button（避免抢走长按）；点按展开、长按排序。
/// 字号：标题 15 / 徽章 11 / 副文 10 / 数值 12 bold / 状态 10。
struct BalanceCardView: View {
    let snapshot: BalanceSnapshot
    var emphasized: Bool = false
    /// 排序模式：不展开，便于长按 / 右侧 ↑↓
    var isReorderMode: Bool = false
    /// 点按选中（供首页高亮与「打开后台」）；与展开同时发生。
    var onSelect: (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil
    /// 默认折叠，与设置页折叠卡一致。
    @State private var isExpanded = false
    @State private var isHovering = false
    @State private var isPressing = false
    /// 长按成功后吞掉随后的 tap，避免展开
    @State private var suppressNextTap = false

    var body: some View {
        cardContent
            .onAppear {
                if isReorderMode { isExpanded = false }
            }
            .onChange(of: isReorderMode) { _, on in
                if on { isExpanded = false }
            }
            .scaleEffect(isPressing ? 0.985 : (isHovering && !isReorderMode ? 1.015 : 1.0))
            .shadow(
                color: SBTheme.accent.opacity(isHovering && !isPressing && !isReorderMode ? 0.18 : 0),
                radius: isHovering && !isPressing && !isReorderMode ? 10 : 0,
                y: isHovering && !isPressing && !isReorderMode ? 3 : 0
            )
            .contentShape(RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous))
            // 长按优先：不用 Button，稍短时长 + 允许轻微移动
            .onLongPressGesture(
                minimumDuration: 0.32,
                maximumDistance: 48,
                pressing: { pressing in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressing = pressing
                    }
                },
                perform: {
                    guard !isReorderMode else { return }
                    suppressNextTap = true
                    onLongPress?()
                }
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    if suppressNextTap {
                        suppressNextTap = false
                        return
                    }
                    guard !isReorderMode else { return }
                    onSelect?()
                    AppMotion.toggleExpand($isExpanded)
                }
            )
            .contextMenu {
                if !isReorderMode {
                    Button {
                        onLongPress?()
                    } label: {
                        Label("排序卡片", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
            .onHover { hovering in
                withAnimation(AppMotion.hover) {
                    isHovering = hovering
                }
            }
            .animation(AppMotion.hover, value: isHovering)
            .animation(.easeOut(duration: 0.1), value: isPressing)
            // 禁止内容 ideal 宽度撑破固定面板
            .fixedSize(horizontal: false, vertical: true)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 10 : 0) {
            headerRow

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
        .contentShape(RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous))
        // 展开只动卡片内部，不带动外层窗体
        .animation(AppMotion.expand, value: isExpanded)
        .animation(AppMotion.hover, value: isHovering)
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
        if snapshot.status == .unknown, snapshot.amount == nil {
            return snapshot.detail.isEmpty ? "查询中…" : snapshot.detail
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

    @ViewBuilder
    private var providerBadge: some View {
        if let kind = snapshot.providerKind {
            ProviderLogoView(kind: kind, size: 24)
        } else {
            ZStack {
                Circle()
                    .fill(SBTheme.accent.opacity(0.85))
                    .frame(width: 24, height: 24)
                Text(snapshot.source == .platformEmail ? "邮" : "?")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
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
        // 无总额/百分比时不画「假满」进度
        return 0
    }

    private func formatNum(_ v: Double) -> String {
        if v >= 100 { return String(format: "%.0f", v) }
        return String(format: "%.2f", v)
    }

    private var cardBackground: some View {
        // 高亮只跟「选中」走；展开/折叠不改变描边与底色（其它卡一律正常）
        let selected = emphasized || snapshot.status == .setup
        let strokeColor: Color = {
            if selected || isHovering { return SBTheme.selectionStroke }
            return SBTheme.cardStroke
        }()
        let fill: Color = {
            if selected { return SBTheme.cardTint }
            if isHovering { return SBTheme.cardTint.opacity(0.55) }
            return SBTheme.panel
        }()
        // 选中描边更明显；悬停略加粗；展开本身不加粗
        let lineWidth: CGFloat = selected ? 1.5 : (isHovering ? 1.2 : 1)
        return RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: lineWidth)
            )
            .shadow(
                color: Color.black.opacity(selected ? 0.2 : (isHovering ? 0.2 : 0.16)),
                radius: selected || isHovering ? 10 : 8,
                y: 2
            )
    }
}
