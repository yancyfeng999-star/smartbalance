import Foundation

public enum SupportAccessibilityID: String, Sendable, Equatable, CaseIterable {
    case navSettings = "nav.settings"
    case navUsage = "nav.usage"
    case navBack = "nav.back"
    case navDone = "nav.done"
    case navRefresh = "nav.refresh"
    case navHelp = "nav.help"
    case navDiagnostics = "nav.diagnostics"
    case errorRetry = "error.retry"
    case errorHelp = "error.help"
    case errorSettings = "error.settings"
    case errorReenter = "error.reenterCredentials"
    case errorLogs = "error.openLogs"
    case errorExport = "error.exportDiagnostics"
    case errorRestore = "error.restoreBackup"
    case usageChartSummary = "usage.chart.summary"
}

public enum SupportAccessibilityTrait: String, Sendable, Equatable {
    case button
    case selected
    case header
}

public struct SupportAccessibilityLabel: Equatable, Sendable {
    public var identifier: String
    public var labelKey: String
    public var isSelected: Bool
    public var traits: Set<SupportAccessibilityTrait>

    public init(
        identifier: String,
        labelKey: String,
        isSelected: Bool,
        traits: Set<SupportAccessibilityTrait>
    ) {
        self.identifier = identifier
        self.labelKey = labelKey
        self.isSelected = isSelected
        self.traits = traits
    }
}

public enum SupportAccessibilityCatalog: Sendable {
    public static let navigationActions: [SupportAccessibilityID] = [
        .navSettings,
        .navUsage,
        .navBack,
        .navDone,
        .navRefresh,
        .navHelp,
        .navDiagnostics,
    ]

    public static func label(
        for identifier: SupportAccessibilityID,
        selected: Bool
    ) -> SupportAccessibilityLabel {
        var traits: Set<SupportAccessibilityTrait> = [.button]
        if selected {
            traits.insert(.selected)
        }
        return SupportAccessibilityLabel(
            identifier: identifier.rawValue,
            labelKey: labelKey(for: identifier),
            isSelected: selected,
            traits: traits
        )
    }

    public static func labelKey(for identifier: SupportAccessibilityID) -> String {
        switch identifier {
        case .navSettings: return "home.settings"
        case .navUsage: return "home.usage"
        case .navBack: return "nav.back"
        case .navDone: return "nav.done"
        case .navRefresh: return "refresh.action"
        case .navHelp: return "help.open"
        case .navDiagnostics: return "diagnostics.title"
        case .errorRetry: return "error.retry"
        case .errorHelp: return "error.help"
        case .errorSettings: return "error.settings"
        case .errorReenter: return "error.reenter"
        case .errorLogs: return "error.logs"
        case .errorExport: return "error.export"
        case .errorRestore: return "error.restore"
        case .usageChartSummary: return "usage.chart.line"
        }
    }

    public static func identifier(for action: ErrorNextAction) -> String {
        switch action {
        case .retry: return SupportAccessibilityID.errorRetry.rawValue
        case .openSettings: return SupportAccessibilityID.errorSettings.rawValue
        case .reenterCredentials: return SupportAccessibilityID.errorReenter.rawValue
        case .openLogs: return SupportAccessibilityID.errorLogs.rawValue
        case .exportDiagnostics: return SupportAccessibilityID.errorExport.rawValue
        case .restoreBackup: return SupportAccessibilityID.errorRestore.rawValue
        case .viewHelp: return SupportAccessibilityID.errorHelp.rawValue
        }
    }

    public static func labelKey(for action: ErrorNextAction) -> String {
        switch action {
        case .retry: return "error.retry"
        case .openSettings: return "error.settings"
        case .reenterCredentials: return "error.reenter"
        case .openLogs: return "error.logs"
        case .exportDiagnostics: return "error.export"
        case .restoreBackup: return "error.restore"
        case .viewHelp: return "error.help"
        }
    }
}

public enum UsageChartTextSummary: Sendable {
    public static let accessibilityIdentifier = SupportAccessibilityID.usageChartSummary.rawValue
    public static let reliesOnColorAlone = false

    public static func line(
        periodLabel: String,
        total: String,
        pointCount: Int,
        language: AppLanguage
    ) -> String {
        LocalizationCatalog.format(
            "usage.chart.line",
            language: language,
            args: [periodLabel, total, "\(pointCount)"]
        )
    }

    public static func providerValue(
        amount: String,
        unit: String,
        qualityKey: String,
        language: AppLanguage
    ) -> String {
        LocalizationCatalog.format(
            "usage.chart.provider",
            language: language,
            args: [amount, unit, LocalizationCatalog.string(qualityKey, language: language)]
        )
    }
}
