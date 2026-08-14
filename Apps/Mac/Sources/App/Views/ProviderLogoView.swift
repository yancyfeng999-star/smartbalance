import SwiftUI
import AppKit
import Domain

/// 平台 logo：优先资源目录 `Provider_<kind>`，否则渐变字母回退。
struct ProviderLogoView: View {
    let kind: ProviderKind
    var size: CGFloat = 24
    var showRing: Bool = true

    var body: some View {
        Group {
            if let image = NSImage(named: kind.logoAssetName) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay {
                        if showRing {
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        }
                    }
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: kind.logoFallbackColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(kind.logoFallbackLetter)
                        .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(kind.displayName)
    }
}

extension ProviderKind {
    /// Asset catalog name, e.g. `Provider_deepseek`
    public var logoAssetName: String { "Provider_\(rawValue)" }

    public var logoFallbackLetter: String {
        switch self {
        case .deepseek: "D"
        case .newapi: "N"
        case .openrouter: "O"
        case .viraltok: "V"
        case .laozhang: "张"
        case .dmxapi: "X"
        case .kimi: "K"
        case .volcengine: "火"
        case .mimo: "米"
        case .minimax: "M"
        case .apinebula: "N"
        case .unsupported: "?"
        }
    }

    public var logoFallbackColors: [Color] {
        switch self {
        case .deepseek: [Color(red: 0.25, green: 0.55, blue: 0.95), Color(red: 0.2, green: 0.4, blue: 0.9)]
        case .newapi: [Color(red: 0.45, green: 0.35, blue: 0.95), Color(red: 0.35, green: 0.25, blue: 0.85)]
        case .openrouter: [Color(red: 0.55, green: 0.25, blue: 0.75), Color(red: 0.45, green: 0.2, blue: 0.65)]
        case .viraltok: [Color(red: 0.15, green: 0.65, blue: 0.45), Color(red: 0.1, green: 0.5, blue: 0.35)]
        case .laozhang: [Color(red: 0.95, green: 0.55, blue: 0.20), Color(red: 0.9, green: 0.4, blue: 0.15)]
        case .dmxapi: [Color(red: 0.09, green: 0.64, blue: 0.72), Color(red: 0.05, green: 0.5, blue: 0.6)]
        case .kimi: [Color(red: 0.25, green: 0.25, blue: 0.28), Color(red: 0.15, green: 0.15, blue: 0.18)]
        case .volcengine: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.1, green: 0.3, blue: 0.85)]
        case .mimo: [Color(red: 0.95, green: 0.30, blue: 0.25), Color(red: 0.85, green: 0.2, blue: 0.2)]
        case .minimax: [Color(red: 0.55, green: 0.25, blue: 0.95), Color(red: 0.4, green: 0.15, blue: 0.85)]
        case .apinebula: [Color(red: 0.20, green: 0.55, blue: 0.90), Color(red: 0.12, green: 0.35, blue: 0.75)]
        case .unsupported: [Color(red: 0.45, green: 0.45, blue: 0.48), Color(red: 0.32, green: 0.32, blue: 0.35)]
        }
    }
}
