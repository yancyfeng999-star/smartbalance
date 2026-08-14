import Foundation

public enum PrimaryNavDestination: String, CaseIterable, Sendable, Equatable {
    case home
    case usage
    case settings
}

public enum SupportDestination: String, CaseIterable, Sendable, Equatable {
    case diagnostics
    case help
    case troubleshooting
    case transfer
    case backup
    case updates
    case restorePreview
}

public enum MenuSurface: String, Sendable, Equatable {
    case home
    case usage
    case settings
    case diagnostics
    case help
    case troubleshooting
    case transfer
    case backup
    case updates
    case restorePreview

    public init(_ destination: PrimaryNavDestination) {
        switch destination {
        case .home: self = .home
        case .usage: self = .usage
        case .settings: self = .settings
        }
    }
}

public enum SupportEntryPoint: String, Sendable, Equatable {
    case settings
    case errorBanner
    case primaryTab
}

public enum SupportKeyboardKey: String, Sendable, Equatable {
    case escape
    case `return`
    case tab
}

public enum SupportKeyboardAction: String, Sendable, Equatable {
    case goBack
    case confirm
    case moveFocus
}

public enum SupportFocusTarget: String, CaseIterable, Sendable, Equatable {
    case refresh
    case settings
    case dashboard
    case usage
    case quit
    case back
    case done
}

public enum SupportFocusPolicy: Sendable {
    public static func tabOrder(for surface: MenuSurface) -> [SupportFocusTarget] {
        switch surface {
        case .home:
            return [.refresh, .settings, .dashboard, .usage, .quit]
        case .usage, .diagnostics, .help, .troubleshooting, .transfer, .backup, .updates, .restorePreview:
            return [.back]
        case .settings:
            return [.back, .done]
        }
    }

    public static func next(_ current: SupportFocusTarget?, surface: MenuSurface) -> SupportFocusTarget? {
        let order = tabOrder(for: surface)
        guard let current, let index = order.firstIndex(of: current) else {
            return order.first
        }
        return order[(index + 1) % order.count]
    }
}

public enum MenuNavAction: Equatable, Sendable {
    case openHome
    case openUsage
    case openSettings
    case openDiagnostics
    case openHelp
    case openHelpTopic(HelpTopicID)
    case back
    case done
    case keyboard(SupportKeyboardKey)
}

public struct MenuNavState: Equatable, Sendable {
    public var primary: PrimaryNavDestination
    public var support: SupportDestination?
    public var helpTopic: HelpTopicID?

    public init(
        primary: PrimaryNavDestination,
        support: SupportDestination? = nil,
        helpTopic: HelpTopicID? = nil
    ) {
        self.primary = primary
        self.support = support
        self.helpTopic = helpTopic
    }
}

public enum MenuNavigationPolicy: Sendable {
    public static let primaryDestinations: [PrimaryNavDestination] = [
        .home, .usage, .settings,
    ]

    public static func isPrimary(_ surface: MenuSurface) -> Bool {
        switch surface {
        case .home, .usage, .settings:
            return true
        case .diagnostics, .help, .troubleshooting, .transfer, .backup, .updates, .restorePreview:
            return false
        }
    }

    public static func destination(for action: MenuNavAction) -> PrimaryNavDestination? {
        switch action {
        case .openHome: return .home
        case .openUsage: return .usage
        case .openSettings, .done: return .settings
        default: return nil
        }
    }

    public static func entryPoints(for destination: SupportDestination) -> [SupportEntryPoint] {
        switch destination {
        case .help, .troubleshooting, .diagnostics:
            return [.settings, .errorBanner]
        case .transfer, .backup, .updates, .restorePreview:
            return [.settings]
        }
    }

    public static func headerTitleKey(for surface: MenuSurface) -> String {
        switch surface {
        case .home: return "home.title"
        case .usage: return "usage.title"
        case .settings: return "settings.title"
        case .diagnostics: return "diagnostics.title"
        case .help: return "help.title"
        case .troubleshooting: return "help.topic.title"
        case .transfer: return "settings.transfer.title"
        case .backup: return "settings.backup.title"
        case .updates: return "update.details.title"
        case .restorePreview: return "restore.preview.title"
        }
    }

    public static func backLabelKey(for surface: MenuSurface) -> String {
        switch surface {
        case .home:
            return "nav.done"
        case .usage, .settings, .diagnostics, .help, .troubleshooting,
             .transfer, .backup, .updates, .restorePreview:
            return "nav.back"
        }
    }

    public static func isSelected(_ destination: PrimaryNavDestination, in state: MenuNavState) -> Bool {
        state.primary == destination
    }

    public static func keyboardAction(
        _ key: SupportKeyboardKey,
        state: MenuNavState
    ) -> SupportKeyboardAction {
        switch key {
        case .escape:
            return .goBack
        case .return:
            return .confirm
        case .tab:
            return .moveFocus
        }
    }

    public static func apply(_ action: MenuNavAction, to state: MenuNavState) -> MenuNavState {
        var next = state
        switch action {
        case .openHome:
            next.primary = .home
            next.support = nil
            next.helpTopic = nil
        case .openUsage:
            next.primary = .usage
            next.support = nil
            next.helpTopic = nil
        case .openSettings:
            next.primary = .settings
            next.support = nil
            next.helpTopic = nil
        case .openDiagnostics:
            next.support = .diagnostics
            next.helpTopic = nil
        case .openHelp:
            next.support = .help
            next.helpTopic = nil
        case .openHelpTopic(let topic):
            next.support = .help
            next.helpTopic = topic
        case .back, .keyboard(.escape):
            next = goBack(next)
        case .done:
            next.primary = .home
            next.support = nil
            next.helpTopic = nil
        case .keyboard(.return):
            next = confirm(next)
        case .keyboard(.tab):
            break
        }
        return next
    }

    public static func surface(
        primary: PrimaryNavDestination,
        support: SupportDestination?,
        helpTopic: HelpTopicID?,
        restorePreviewVisible: Bool = false
    ) -> MenuSurface {
        if helpTopic != nil { return .troubleshooting }
        if restorePreviewVisible { return .restorePreview }
        if let support {
            switch support {
            case .diagnostics: return .diagnostics
            case .help: return .help
            case .troubleshooting: return .troubleshooting
            case .transfer: return .transfer
            case .backup: return .backup
            case .updates: return .updates
            case .restorePreview: return .restorePreview
            }
        }
        return MenuSurface(primary)
    }

    private static func confirm(_ state: MenuNavState) -> MenuNavState {
        if state.helpTopic != nil || state.support != nil {
            return state
        }
        if state.primary == .settings {
            return apply(.done, to: state)
        }
        return state
    }

    private static func goBack(_ state: MenuNavState) -> MenuNavState {
        var next = state
        if next.helpTopic != nil {
            next.helpTopic = nil
            next.support = .help
            return next
        }
        if next.support != nil {
            next.support = nil
            return next
        }
        if next.primary != .home {
            next.primary = .home
        }
        return next
    }
}
