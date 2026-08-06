import SwiftUI
import Domain

/// 嵌在一级设置卡内部的二级折叠卡（外层大卡 → 内层小卡）。
struct NestedSettingsCard<Content: View>: View {
    /// SF Symbol 回退（无 logo 时）
    var icon: String = "app.fill"
    var iconColors: [Color] = [SBTheme.accent, SBTheme.accent.opacity(0.7)]
    /// 有平台 kind 时优先显示品牌 logo
    var providerKind: ProviderKind? = nil
    let title: String
    let subtitle: String
    var badge: String? = nil
    var badgeColor: Color = SBTheme.accent
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                AppMotion.toggleExpand($isExpanded)
            } label: {
                HStack(spacing: 8) {
                    if let providerKind {
                        ProviderLogoView(kind: providerKind, size: 22)
                    } else {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: iconColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 22, height: 22)
                            Image(systemName: icon)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SBTheme.text)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SBTheme.muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(badgeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(badgeColor.opacity(0.14))
                            )
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(SBTheme.muted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(AppMotion.chevron, value: isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .overlay(SBTheme.stroke)
                        .padding(.top, 10)
                        .padding(.bottom, 10)

                    content()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .transition(AppMotion.expandContent)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SBTheme.bg.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(SBTheme.stroke, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(AppMotion.expand, value: isExpanded)
    }
}
