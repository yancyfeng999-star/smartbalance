import SwiftUI

/// 智额风格可折叠设置卡：点标题展开，内容从标题下方展开。
struct SettingsExpandableCard<Content: View>: View {
    let icon: String
    let iconColors: [Color]
    let title: String
    let subtitle: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: iconColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(SBTheme.text)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SBTheme.muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SBTheme.muted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().overlay(SBTheme.stroke)
                    content()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 12)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    )
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                .fill(SBTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                        .stroke(SBTheme.cardStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 5, y: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous))
    }
}
