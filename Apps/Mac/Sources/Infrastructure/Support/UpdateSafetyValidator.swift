import Foundation
import Domain

public struct UpdateSafetyValidator: Sendable {
    public init() {}

    public func validate(
        _ candidate: UpdateCandidate,
        integrity: PackageIntegrityReport? = nil
    ) -> UpdateValidationResult {
        var issues: [UpdateValidationIssue] = []

        if UpdateVersion.parse(candidate.targetVersion) == nil {
            issues.append(.malformedTargetVersion)
        } else if let comparison = UpdateVersion.compare(candidate.targetVersion, candidate.currentVersion) {
            if comparison <= 0 {
                issues.append(.versionNotNewer)
            }
        } else {
            issues.append(.malformedTargetVersion)
        }

        if let osComparison = UpdateVersion.compare(candidate.minimumMacOS, candidate.currentMacOS) {
            if osComparison > 0 {
                issues.append(.incompatibleMinimumOS)
            }
        } else {
            issues.append(.incompatibleMinimumOS)
        }

        if candidate.assetURL.scheme?.lowercased() != "https" {
            issues.append(.urlNotHTTPS)
        }

        if !UpdateAssetName.isAllowed(candidate.assetFileName) {
            issues.append(.assetExtensionNotAllowed)
        }

        if candidate.assetByteSize <= 0 {
            issues.append(.sizeZero)
        } else if candidate.assetByteSize > candidate.maxByteSize {
            issues.append(.sizeExceedsLimit)
        }

        var checksumStatus: UpdateChecksumStatus = .notChecked
        var checksumDisplay: UpdateChecksumDisplay = .pending
        let digest = resolvedDigest(for: candidate)
        let manifest = candidate.checksumManifestText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let listedManifestMissing = candidate.checksumManifestRequired && manifest.isEmpty

        if candidate.checksumManifestFetchFailed || listedManifestMissing {
            checksumStatus = .unverifiable
            checksumDisplay = .failed
            issues.append(.checksumUnavailable)
        } else if manifest.isEmpty {
            checksumStatus = .unverifiable
            checksumDisplay = .unverifiable
            issues.append(.checksumMissing)
        } else if let digest {
            if SHA256Verifier.matches(fileName: candidate.assetFileName, digest: digest, manifest: manifest) {
                checksumStatus = .verified
                checksumDisplay = .verified
            } else {
                checksumStatus = .mismatch
                checksumDisplay = .failed
                issues.append(.checksumMismatch)
            }
        } else {
            checksumStatus = .notChecked
            checksumDisplay = .pending
        }

        if let integrity {
            if !integrity.structureValid {
                issues.append(.packageStructureInvalid)
            }
            if integrity.signatureValid == false {
                issues.append(.packageSignatureInvalid)
            }
        }

        return UpdateValidationResult.making(
            issues: issues,
            checksumStatus: checksumStatus,
            checksumDisplay: checksumDisplay
        )
    }

    private func resolvedDigest(for candidate: UpdateCandidate) -> String? {
        if let digest = candidate.downloadedFileSHA256, !digest.isEmpty {
            return digest.lowercased()
        }
        guard let url = candidate.downloadedFileURL else { return nil }
        return try? SHA256Verifier.hexDigest(ofFile: url)
    }
}

public protocol PackageIntegrityInspecting: Sendable {
    func inspect(fileURL: URL) -> PackageIntegrityReport
}

public struct DefaultPackageIntegrityInspector: PackageIntegrityInspecting {
    public init() {}

    public func inspect(fileURL: URL) -> PackageIntegrityReport {
        let ext = fileURL.pathExtension.lowercased()
        let structureValid: Bool
        switch ext {
        case "pkg":
            structureValid = hasMagic(fileURL, magic: Data("xar!".utf8))
        case "dmg":
            structureValid = hasDMGTrailer(fileURL)
        default:
            structureValid = false
        }
        return PackageIntegrityReport(
            structureValid: structureValid,
            signatureValid: inspectSignature(fileURL)
        )
    }

    private func hasMagic(_ url: URL, magic: Data) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let prefix = (try? handle.read(upToCount: magic.count)) ?? Data()
        return prefix == magic
    }

    private func hasDMGTrailer(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        guard size >= 512 else { return false }
        do {
            try handle.seek(toOffset: size - 512)
            let trailer = try handle.read(upToCount: 512) ?? Data()
            return trailer.starts(with: Data("koly".utf8))
        } catch {
            return false
        }
    }

    /// `true` signed and valid, `false` invalid, `nil` unsigned / unchecked.
    private func inspectSignature(_ url: URL) -> Bool? {
        guard url.pathExtension.lowercased() == "pkg" else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/pkgutil")
        process.arguments = ["--check-signature", url.path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8)?.lowercased() ?? ""
        if text.contains("no signature") || text.contains("not signed") {
            return nil
        }
        if text.contains("invalid") || text.contains("untrusted") || process.terminationStatus != 0 {
            return false
        }
        if text.contains("signed") {
            return true
        }
        return nil
    }
}

public struct PackageInstallEnvironment: Sendable {
    public var inspector: any PackageIntegrityInspecting
    public var expandPackage: (@Sendable (URL, URL) throws -> URL)?
    public var launchApplyScript: (@Sendable (URL) throws -> Void)?

    public init(
        inspector: any PackageIntegrityInspecting = DefaultPackageIntegrityInspector(),
        expandPackage: (@Sendable (URL, URL) throws -> URL)? = nil,
        launchApplyScript: (@Sendable (URL) throws -> Void)? = nil
    ) {
        self.inspector = inspector
        self.expandPackage = expandPackage
        self.launchApplyScript = launchApplyScript
    }

    public static var live: PackageInstallEnvironment { PackageInstallEnvironment() }
}
