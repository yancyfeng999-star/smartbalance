import SwiftUI
import Domain

struct SupportMotionChrome: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .transaction { transaction in
                if reduceMotion {
                    transaction.disablesAnimations = true
                }
            }
    }
}

struct SupportKeyboardHost: ViewModifier {
    let onEscape: () -> Void
    var onReturn: (() -> Void)? = nil

    func body(content: Content) -> some View {
        content
            .onExitCommand(perform: onEscape)
            .background(alignment: .topLeading) {
                Button(action: onEscape) {
                    Color.clear.frame(width: 1, height: 1)
                }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0.001)
                .accessibilityHidden(true)
                if let onReturn {
                    Button(action: onReturn) {
                        Color.clear.frame(width: 1, height: 1)
                    }
                    .keyboardShortcut(.defaultAction)
                    .opacity(0.001)
                    .accessibilityHidden(true)
                }
            }
    }
}

enum SupportPalette {
    static func text(contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? Color.primary : SBTheme.text
    }

    static func muted(contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? Color.primary.opacity(0.72) : SBTheme.muted
    }

    static func danger(contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? Color.red : SBTheme.danger
    }

    static func stroke(contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? Color.primary.opacity(0.55) : SBTheme.stroke
    }

    static func cardStroke(contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? Color.primary.opacity(0.65) : SBTheme.cardStroke
    }
}

extension View {
    func supportPageChrome() -> some View {
        modifier(SupportMotionChrome())
    }

    func supportKeyboard(onEscape: @escaping () -> Void, onReturn: (() -> Void)? = nil) -> some View {
        modifier(SupportKeyboardHost(onEscape: onEscape, onReturn: onReturn))
    }

    func supportButtonLabel(_ label: String, identifier: String, selected: Bool = false) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
