import Foundation
import Domain

public struct DiagnosticsService: Sendable {
    public init() {}

    public func collect(
        _ context: DiagnosticsContext,
        options: DiagnosticOptions = .default
    ) -> DiagnosticReport {
        let checks = DiagnosticCheckID.allCases.map { makeCheck($0, context) }
        let lines: [String]
        if options.includeSanitizedLogs, let url = context.logFileURL {
            lines = AppLog.tailLines(from: url, maxLines: options.maxLogLines, maxBytes: options.maxLogReadBytes)
                .map { PrivacyRedactor.redact($0) }
        } else {
            lines = []
        }
        return DiagnosticReport(
            generatedAt: context.now,
            appVersion: context.appVersion,
            build: context.build,
            osVersion: context.osVersion,
            architecture: context.architecture,
            launchMode: context.launchMode.rawValue,
            schemaVersion: context.schemaVersion,
            checks: checks,
            sanitizedLogLines: lines,
            keychainStatus: context.keychainStatus,
            notificationAuthorization: context.notificationAuthorization.rawValue,
            refresh: context.refresh,
            providers: context.providers,
            usage: context.usage,
            directories: DiagnosticDirectories(
                applicationSupport: context.applicationSupport,
                logs: context.logs,
                temporary: context.temporary
            ),
            lastMigrationResult: context.lastMigrationResult,
            lastBackupResult: context.lastBackupResult,
            lastRestoreResult: context.lastRestoreResult
        )
    }

    public static func makeLiveContext(
        settings: AppSettings,
        usage: UsageHistoryDocument,
        usageSaveError: String?,
        refresh: DiagnosticRefreshSummary,
        keychainStatus: DiagnosticKeychainStatus,
        notificationAuthorization: NotificationAuthorizationState,
        appVersion: String,
        build: String,
        now: Date = Date(),
        settingsFileURL: URL? = nil,
        usageHistoryFileURL: URL? = nil,
        applicationSupportDirectory: URL? = nil
    ) -> DiagnosticsContext {
        let support = applicationSupportDirectory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SmartBalance", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let logsDir = AppLog.directoryURL
        let tempDir = FileManager.default.temporaryDirectory
        let settingsURL = settingsFileURL ?? support.appendingPathComponent("settings.json")
        let usageURL = usageHistoryFileURL ?? support.appendingPathComponent("usage-history.json")
        let settingsInspection = inspectSettings(settingsURL)
        let usageReadable = inspectUsageReadable(usageURL)
        let snapshots = classifySnapshots(in: support)
        let os = ProcessInfo.processInfo.operatingSystemVersion

        return DiagnosticsContext(
            now: now,
            appVersion: appVersion,
            build: build,
            osVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            architecture: CompatibilityChecker.currentArchitecture().rawValue,
            launchMode: .menuBar,
            schemaVersion: settingsInspection.schemaVersion,
            applicationSupport: probe(support, primaryFile: settingsURL),
            logs: probe(logsDir, primaryFile: AppLog.fileURL),
            temporary: probe(tempDir, primaryFile: nil),
            settingsReadable: settingsInspection.readable,
            settingsSchemaSupported: settingsInspection.schemaSupported,
            usageHistoryReadable: usageReadable,
            lastMigrationResult: snapshots.migration,
            lastBackupResult: snapshots.backup,
            lastRestoreResult: snapshots.restore,
            keychainStatus: keychainStatus,
            notificationAuthorization: notificationAuthorization,
            refresh: refresh,
            providers: settings.accounts.map(DiagnosticProviderSummary.init(account:)),
            usage: DiagnosticUsageSummary(
                document: usage,
                saveErrorClassification: usageSaveError ?? "none"
            ),
            logFileURL: AppLog.fileURL
        )
    }

    private func makeCheck(_ id: DiagnosticCheckID, _ context: DiagnosticsContext) -> DiagnosticCheck {
        switch id {
        case .appVersion:
            return DiagnosticCheck(
                id: id,
                status: .ok,
                detailKey: "diagnostics.detail.appVersion.ok",
                redactedDetail: "\(context.appVersion) (\(context.build))"
            )
        case .macos:
            return DiagnosticCheck(
                id: id,
                status: .ok,
                detailKey: "diagnostics.detail.macos.ok",
                redactedDetail: context.osVersion
            )
        case .architecture:
            return DiagnosticCheck(
                id: id,
                status: context.architecture == DiagnosticLaunchMode.unknown.rawValue ? .warning : .ok,
                detailKey: "diagnostics.detail.architecture.\(context.architecture)",
                redactedDetail: context.architecture
            )
        case .launchMode:
            return DiagnosticCheck(
                id: id,
                status: .ok,
                detailKey: "diagnostics.detail.launchMode.\(context.launchMode.rawValue)",
                redactedDetail: context.launchMode.rawValue
            )
        case .schema:
            return DiagnosticCheck(
                id: id,
                status: context.settingsSchemaSupported ? .ok : .failed,
                detailKey: context.settingsSchemaSupported
                    ? "diagnostics.detail.schema.ok"
                    : "diagnostics.detail.schema.unsupported",
                redactedDetail: context.schemaVersion.map(String.init)
            )
        case .applicationSupport:
            return directoryCheck(
                id,
                context.applicationSupport,
                okKey: "diagnostics.detail.applicationSupport.ok",
                failKey: "diagnostics.detail.applicationSupport.unwritable"
            )
        case .logs:
            return directoryCheck(
                id,
                context.logs,
                okKey: "diagnostics.detail.logs.ok",
                failKey: "diagnostics.detail.logs.unwritable"
            )
        case .temporary:
            return directoryCheck(
                id,
                context.temporary,
                okKey: "diagnostics.detail.temporary.ok",
                failKey: "diagnostics.detail.temporary.unwritable"
            )
        case .settings:
            return DiagnosticCheck(
                id: id,
                status: context.settingsReadable ? .ok : .failed,
                detailKey: context.settingsReadable
                    ? "diagnostics.detail.settings.ok"
                    : "diagnostics.detail.settings.unreadable"
            )
        case .usageHistory:
            return DiagnosticCheck(
                id: id,
                status: context.usageHistoryReadable ? .ok : .warning,
                detailKey: context.usageHistoryReadable
                    ? "diagnostics.detail.usageHistory.ok"
                    : "diagnostics.detail.usageHistory.unreadable"
            )
        case .migration:
            return resultCheck(id, context.lastMigrationResult, prefix: "migration")
        case .backup:
            return resultCheck(id, context.lastBackupResult, prefix: "backup")
        case .restore:
            return resultCheck(id, context.lastRestoreResult, prefix: "restore")
        case .keychain:
            let status: DiagnosticStatus
            switch context.keychainStatus {
            case .available: status = .ok
            case .unavailable: status = .failed
            case .unknown: status = .unknown
            }
            return DiagnosticCheck(
                id: id,
                status: status,
                detailKey: "diagnostics.detail.keychain.\(context.keychainStatus.rawValue)",
                redactedDetail: context.keychainStatus.rawValue
            )
        case .notifications:
            return DiagnosticCheck(
                id: id,
                status: notificationStatus(context.notificationAuthorization),
                detailKey: "diagnostics.detail.notifications.\(context.notificationAuthorization.rawValue)",
                redactedDetail: context.notificationAuthorization.rawValue
            )
        case .refresh:
            return DiagnosticCheck(
                id: id,
                status: refreshStatus(context.refresh),
                detailKey: "diagnostics.detail.refresh.\(context.refresh.state)",
                redactedDetail: "\(context.refresh.succeededCount)/\(context.refresh.failedCount)"
            )
        case .providers:
            return DiagnosticCheck(
                id: id,
                status: .ok,
                detailKey: "diagnostics.detail.providers.ok",
                redactedDetail: String(context.providers.count)
            )
        case .usage:
            let classification = context.usage.saveErrorClassification ?? "none"
            let failed = classification != "none" && classification != "recovered"
            return DiagnosticCheck(
                id: id,
                status: failed ? .warning : .ok,
                detailKey: failed ? "diagnostics.detail.usage.warning" : "diagnostics.detail.usage.ok",
                redactedDetail: "\(context.usage.recordCount) \(classification)"
            )
        }
    }

    private func directoryCheck(
        _ id: DiagnosticCheckID,
        _ probe: DiagnosticDirectoryProbe,
        okKey: String,
        failKey: String
    ) -> DiagnosticCheck {
        DiagnosticCheck(
            id: id,
            status: probe.writable ? .ok : .failed,
            detailKey: probe.writable ? okKey : failKey,
            redactedDetail: [
                probe.posixPermissions,
                probe.fileSizeBytes.map { "\($0)B" },
            ].compactMap { $0 }.joined(separator: " ")
        )
    }

    private func resultCheck(_ id: DiagnosticCheckID, _ result: String, prefix: String) -> DiagnosticCheck {
        let status: DiagnosticStatus
        switch result {
        case "ok": status = .ok
        case "failed": status = .failed
        case "none": status = .ok
        default: status = .unknown
        }
        return DiagnosticCheck(
            id: id,
            status: status,
            detailKey: "diagnostics.detail.\(prefix).\(result)",
            redactedDetail: result
        )
    }

    private func notificationStatus(_ state: NotificationAuthorizationState) -> DiagnosticStatus {
        switch state {
        case .authorized, .provisional: return .ok
        case .notDetermined, .denied, .restricted, .unknown: return .warning
        }
    }

    private func refreshStatus(_ summary: DiagnosticRefreshSummary) -> DiagnosticStatus {
        switch summary.state {
        case "failed": return .failed
        case "partiallyFailed": return .warning
        default: return .ok
        }
    }

    private static func probe(_ directory: URL, primaryFile: URL?) -> DiagnosticDirectoryProbe {
        let writable = CompatibilityChecker.canWrite(to: directory)
        let permissions = posixOctal(directory)
        let size: Int64
        if let primaryFile, FileManager.default.fileExists(atPath: primaryFile.path),
           let number = try? FileManager.default.attributesOfItem(atPath: primaryFile.path)[.size] as? NSNumber {
            size = number.int64Value
        } else {
            size = 0
        }
        return DiagnosticDirectoryProbe(writable: writable, posixPermissions: permissions, fileSizeBytes: size)
    }

    private static func posixOctal(_ url: URL) -> String? {
        guard let number = try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber else {
            return nil
        }
        return String(format: "%o", number.uint16Value)
    }

    private static func inspectSettings(_ url: URL) -> (readable: Bool, schemaSupported: Bool, schemaVersion: Int?) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (true, true, nil)
        }
        guard let data = try? Data(contentsOf: url) else {
            return (false, false, nil)
        }
        do {
            let outcome = try SettingsMigration.migrate(data: data)
            return (true, true, outcome.document.schemaVersion)
        } catch SettingsMigrationError.unsupportedSchemaVersion(let version) {
            return (true, false, version)
        } catch {
            return (false, false, nil)
        }
    }

    private static func inspectUsageReadable(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return true }
        guard let data = try? Data(contentsOf: url) else { return false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(UsageHistoryDocument.self, from: data)) != nil
    }

    private static func classifySnapshots(in directory: URL) -> (migration: String, backup: String, restore: String) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return (
            names.contains { $0.contains("schema-migration") } ? "ok" : "none",
            names.contains { $0.contains("settings-write") } ? "ok" : "none",
            names.contains { $0.contains("restore") } ? "ok" : "none"
        )
    }
}
