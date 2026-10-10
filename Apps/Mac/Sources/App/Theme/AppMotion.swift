import SwiftUI

// MARK: - Soft expand from under header

/// 内容从标题下方展开：先上提模糊，再落下清晰。
struct SoftExpandFromHeaderModifier: ViewModifier, Animatable, Sendable {
    /// 0 = 隐藏，1 = 完全显示
    var progress: Double

    nonisolated init(progress: Double) {
        self.progress = progress
    }

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = max(0, min(1, progress))
        let eased = 1 - pow(1 - t, 2.2)
        let offsetY = (1 - eased) * -14
        let scaleY = 0.88 + 0.12 * eased
        let blur = (1 - eased) * 12

        content
            .opacity(eased)
            .blur(radius: blur)
            .scaleEffect(x: 1, y: scaleY, anchor: .top)
            .offset(y: offsetY)
            .compositingGroup()
    }
}

/// 应用统一动效。
enum AppMotion {
    /// 设置卡展开 / 收起
    static let expand: Animation = .spring(response: 0.42, dampingFraction: 0.90)

    /// chevron 跟随
    static let chevron: Animation = .spring(response: 0.36, dampingFraction: 0.88)

    /// 芯片 / 选中
    static let selection: Animation = .spring(response: 0.32, dampingFraction: 0.86)

    /// 首页卡片悬停轻抬
    static let hover: Animation = .easeOut(duration: 0.16)

    /// 列表出现
    static let appear: Animation = .easeOut(duration: 0.35)

    /// 内容从标题底边展开（带初始模糊）
    static var expandContent: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: SoftExpandFromHeaderModifier(progress: 0),
                identity: SoftExpandFromHeaderModifier(progress: 1)
            ),
            removal: .modifier(
                active: SoftExpandFromHeaderModifier(progress: 0),
                identity: SoftExpandFromHeaderModifier(progress: 1)
            )
        )
    }

    static func animation(_ preferred: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : preferred
    }

    static func toggleExpand(_ isExpanded: Binding<Bool>, reduceMotion: Bool = false) {
        if reduceMotion {
            isExpanded.wrappedValue.toggle()
        } else {
            withAnimation(expand) {
                isExpanded.wrappedValue.toggle()
            }
        }
    }

    static func withExpand(_ body: () -> Void, reduceMotion: Bool = false) {
        if reduceMotion {
            body()
        } else {
            withAnimation(expand, body)
        }
    }

    static func withSelection(_ body: () -> Void, reduceMotion: Bool = false) {
        if reduceMotion {
            body()
        } else {
            withAnimation(selection, body)
        }
    }

    /// Skip staggered appear work for large account lists so menu open stays cheap.
    static let largeListStaggerCap = 8
    static let maxAppearStagger: TimeInterval = 0.2

    static func appearDelay(forIndex index: Int, itemCount: Int, reduceMotion: Bool) -> TimeInterval {
        if reduceMotion || itemCount >= largeListStaggerCap { return 0 }
        return min(maxAppearStagger, Double(index) * 0.05)
    }

    static func appearAnimation(forIndex index: Int, itemCount: Int, reduceMotion: Bool) -> Animation? {
        animation(appear.delay(appearDelay(forIndex: index, itemCount: itemCount, reduceMotion: reduceMotion)), reduceMotion: reduceMotion)
    }
}
