import Foundation

public enum UpdateValidationIssue: String, Sendable, Equatable, CaseIterable {
    case versionNotNewer
    case malformedTargetVersion
    case incompatibleMinimumOS
    case urlNotHTTPS
    case assetExtensionNotAllowed
    case sizeZero
    case sizeExceedsLimit
    case checksumMismatch
    case checksumMissing
    case packageSignatureInvalid
    case packageStructureInvalid
    case cancelled
    case timeout
    case insufficientDiskSpace
    case installScriptFailed

    public var localizationKey: String {
        "update.error.\(rawValue)"
    }

    public var blocksInstall: Bool {
        self != .checksumMissing
    }
}

public struct UpdateValidationResult: Sendable, Equatable {
    public var canInstall: Bool
    public var checksumStatus: UpdateChecksumStatus
    public var checksumDisplay: UpdateChecksumDisplay
    public var issues: [UpdateValidationIssue]

    public init(
        canInstall: Bool,
        checksumStatus: UpdateChecksumStatus,
        checksumDisplay: UpdateChecksumDisplay,
        issues: [UpdateValidationIssue]
    ) {
        self.canInstall = canInstall
        self.checksumStatus = checksumStatus
        self.checksumDisplay = checksumDisplay
        self.issues = issues
    }

    public var errorSummaryKeys: [String] {
        issues.map(\.localizationKey)
    }

    public var blockingIssues: [UpdateValidationIssue] {
        issues.filter(\.blocksInstall)
    }

    public static func making(issues: [UpdateValidationIssue], checksumStatus: UpdateChecksumStatus, checksumDisplay: UpdateChecksumDisplay) -> UpdateValidationResult {
        UpdateValidationResult(
            canInstall: issues.allSatisfy { !$0.blocksInstall },
            checksumStatus: checksumStatus,
            checksumDisplay: checksumDisplay,
            issues: issues
        )
    }
}

public struct PackageIntegrityReport: Sendable, Equatable {
    public var structureValid: Bool
    public var signatureValid: Bool?

    public init(structureValid: Bool, signatureValid: Bool? = nil) {
        self.structureValid = structureValid
        self.signatureValid = signatureValid
    }
}
