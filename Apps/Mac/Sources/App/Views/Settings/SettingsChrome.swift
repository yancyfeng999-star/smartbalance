import SwiftUI

/// Shared chrome for settings sections (card shell, labels, fields).
enum SettingsChrome {
    static func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SBTheme.muted)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                .fill(SBTheme.panel)
                .shadow(color: Color.black.opacity(0.04), radius: 5, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                        .stroke(SBTheme.cardStroke, lineWidth: 1)
                )
        )
    }

    static func labelStack(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundStyle(SBTheme.text)
            Text(sub)
                .font(.system(size: 11))
                .foregroundStyle(SBTheme.muted)
        }
    }

    static func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(SBTheme.muted)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
}
