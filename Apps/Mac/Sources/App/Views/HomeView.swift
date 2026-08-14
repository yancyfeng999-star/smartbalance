import SwiftUI
import Domain

struct HomeView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var l10n = L10n.shared
    @State private var animateIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 10) {
            if model.isReorderMode {
                reorderBanner
            }

            homeNoticeBlock

            // 有配置账号就始终走卡片；仅「真的一个账号都没有」才显示引导
            if model.settings.enabledAccounts.isEmpty && model.snapshots.isEmpty {
                emptyState
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 8)
            } else {
                accountList
            }

            if !model.recentAlerts.isEmpty, !model.isReorderMode {
                Text(l10n.t("home.recent_alerts"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SBTheme.muted)
                    .padding(.top, 2)
                ForEach(model.recentAlerts.prefix(2)) { alert in
                    alertRow(alert)
                }
            }
        }
        .onAppear {
            if reduceMotion {
                animateIn = true
            } else {
                withAnimation(AppMotion.appear) {
                    animateIn = true
                }
            }
        }
        .onChange(of: model.snapshots.count) { _, _ in
            animateIn = reduceMotion
            if reduceMotion {
                animateIn = true
            } else {
                withAnimation(AppMotion.appear) {
                    animateIn = true
                }
            }
        }
        .onChange(of: model.settings.accounts.count) { _, _ in
            if model.snapshots.isEmpty, !model.settings.enabledAccounts.isEmpty {
                if reduceMotion {
                    animateIn = true
                } else {
                    animateIn = false
                    withAnimation(AppMotion.appear) {
                        animateIn = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var homeNoticeBlock: some View {
        if !model.isReorderMode, let kind = homeErrorKind {
            ActionableErrorView(presentation: ActionableErrorPolicy.presentation(for: kind)) { action in
                model.performErrorAction(action, kind: kind)
            }
        } else if let notice = homeNoticeText, !model.isReorderMode {
            genericNoticeBanner(notice)
        }
    }

    private var accountList: some View {
        ForEach(Array(model.snapshots.enumerated()), id: \.element.accountId) { index, snap in
            accountRow(snapshot: snap, index: index)
        }
        .animation(reduceMotion ? nil : AppMotion.selection, value: model.isReorderMode)
        .animation(reduceMotion ? nil : AppMotion.selection, value: model.snapshots.map(\.accountId))
    }

    private func accountRow(snapshot snap: BalanceSnapshot, index: Int) -> some View {
        HStack(alignment: .center, spacing: 6) {
            BalanceCardView(
                snapshot: snap,
                emphasized: model.selectedAccountId == snap.accountId && !model.isReorderMode,
                isReorderMode: model.isReorderMode,
                onSelect: { model.selectAccount(id: snap.accountId) },
                onLongPress: { model.enterReorderMode() },
                onErrorAction: { action in
                    let kind = SupportViewMapping.cardKind(
                        status: snap.status,
                        errorMessage: snap.errorMessage
                    ) ?? .refreshFailed
                    model.performErrorAction(action, kind: kind)
                }
            )
            .frame(maxWidth: .infinity)
            .id(snap.accountId)

            if model.isReorderMode {
                reorderControls(accountId: snap.accountId, index: index)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 10)
        .animation(cardAppearAnimation(index: index), value: animateIn)
    }

    private func cardAppearAnimation(index: Int) -> Animation? {
        AppMotion.appearAnimation(
            forIndex: index,
            itemCount: model.snapshots.count,
            reduceMotion: reduceMotion
        )
    }

    private func genericNoticeBanner(_ notice: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(notice)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.warn)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                model.openHelpCenter()
            } label: {
                Text(l10n.t("help.open"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SBTheme.accent)
            }
            .buttonStyle(.plain)
            .supportButtonLabel(l10n.t("help.open"), identifier: SupportAccessibilityID.errorHelp.rawValue)
            if showsDiagnosticsAction {
                Button {
                    model.openDiagnosticsCenter()
                } label: {
                    Text(l10n.t("diagnostics.banner.action"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SBTheme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.t("diagnostics.banner.action"))
            }
            Button {
                model.dismissRefreshNotice()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SBTheme.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n.t("nav.done"))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SBTheme.warn.opacity(0.12))
        )
    }

    private var homeNoticeText: String? {
        if let key = model.refreshNoticeKey {
            return l10n.t(key)
        }
        return model.banner
    }

    private var homeErrorKind: ActionableErrorKind? {
        SupportViewMapping.homeBannerKind(
            noticeKey: model.refreshNoticeKey,
            bannerKey: model.bannerKey,
            usageHealth: model.usageStorageHealth,
            usageDataError: model.usageDataError
        )
    }

    private var showsDiagnosticsAction: Bool {
        DiagnosticBannerPolicy.shouldOfferDiagnostics(
            noticeKey: model.refreshNoticeKey,
            usageDataError: model.usageDataError,
            usageRecoveryNotice: model.usageRecoveryNotice,
            usageHealth: model.usageStorageHealth
        )
    }

    // MARK: - Reorder（对齐智额）

    private var reorderBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SBTheme.accent)
            Text(l10n.t("home.sort_mode"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
            Spacer(minLength: 4)
            Button {
                model.exitReorderMode()
            } label: {
                Text(l10n.t("common.done"))
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
                    Text(l10n.t("home.alert.notified"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(SBTheme.ok)
                }
                if alert.emailed {
                    Text(l10n.t("home.alert.emailed"))
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
            HStack(spacing: 10) {
                Image("AppLogo")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                Text(l10n.t("home.empty.title"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SBTheme.text)
            }
            Text(l10n.t("home.empty.subtitle"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.t("home.empty.step1"))
                Text(l10n.t("home.empty.step2"))
                Text(l10n.t("home.empty.step3"))
                Text(l10n.t("home.empty.step4"))
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(SBTheme.muted)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                model.selectedTab = .settings
            } label: {
                Text(l10n.t("home.empty.action"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(SBTheme.accent))
            }
            .buttonStyle(.plain)
            .supportButtonLabel(
                l10n.t("home.empty.action"),
                identifier: SupportAccessibilityID.errorSettings.rawValue
            )
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
