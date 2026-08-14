import Foundation
import Domain
import Security

public struct CompatibilityChecker: Sendable {
    public init() {}

    public func evaluate(_ context: CompatibilityContext) -> CompatibilityReport {
        let settingsInspection = inspectSettings(context.settingsFileURL)
        let usage = inspectUsageHistory(context.usageHistoryFileURL)

        let checks: [CompatibilityCheck] = CompatibilityCheckID.allCases.map { id in
            switch id {
            case .macos:
                return makeCheck(id, macos(context))
            case .architecture:
                return makeCheck(id, architecture(context.architecture))
            case .applicationSupport:
                return makeCheck(
                    id,
                    context.isApplicationSupportWritable
                        ? (.ok, "compat.appSupport.ok")
                        : (.failed, "compat.appSupport.unwritable")
                )
            case .logs:
                return makeCheck(
                    id,
                    context.isLogsWritable
                        ? (.ok, "compat.logs.ok")
                        : (.failed, "compat.logs.unwritable")
                )
            case .keychain:
                return makeCheck(
                    id,
                    context.keychainAvailable
                        ? (.ok, "compat.keychain.available")
                        : (.failed, "compat.keychain.unavailable")
                )
            case .notifications:
                return makeCheck(id, notifications(context.notificationAuthorization))
            case .settings:
                return makeCheck(id, settingsInspection.settings)
            case .usageHistory:
                return makeCheck(id, usageHealth(context.usageStorageHealth) ?? usage)
            case .schema:
                return makeCheck(id, settingsInspection.schema)
            }
        }

        return CompatibilityReport(
            generatedAt: context.now,
            osVersion: "\(context.macOSMajor).\(context.macOSMinor).\(context.macOSPatch)",
            architecture: context.architecture.rawValue,
            schemaVersion: settingsInspection.schemaVersion,
            checks: checks
        )
    }

    public static func makeLiveContext(
        notificationAuthorization: NotificationAuthorizationState,
        now: Date = Date(),
        settingsFileURL: URL? = nil,
        usageHistoryFileURL: URL? = nil,
        usageStorageHealth: UsageStorageHealth? = nil
    ) -> CompatibilityContext {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SmartBalance", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let logs = AppLog.directoryURL
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return CompatibilityContext(
            now: now,
            macOSMajor: version.majorVersion,
            macOSMinor: version.minorVersion,
            macOSPatch: version.patchVersion,
            minimumMacOSMajor: 15,
            minimumMacOSMinor: 0,
            minimumMacOSPatch: 0,
            architecture: currentArchitecture(),
            applicationSupportDirectory: support,
            logsDirectory: logs,
            isApplicationSupportWritable: canWrite(to: support),
            isLogsWritable: canWrite(to: logs),
            settingsFileURL: settingsFileURL ?? support.appendingPathComponent("settings.json"),
            usageHistoryFileURL: usageHistoryFileURL ?? support.appendingPathComponent("usage-history.json"),
            keychainAvailable: probePlainKeychain(),
            notificationAuthorization: notificationAuthorization,
            currentSettingsSchemaVersion: SettingsDocument.currentSchemaVersion,
            usageStorageHealth: usageStorageHealth
        )
    }

    public static func currentArchitecture() -> CompatibilityArchitecture {
#if arch(arm64)
        return .appleSilicon
#elseif arch(x86_64)
        return .intel
#else
        return .unknown
#endif
    }

    public static func canWrite(to directory: URL) -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            let probe = directory.appendingPathComponent(".sb-write-probe-\(UUID().uuidString)")
            try Data("ok".utf8).write(to: probe, options: .atomic)
            try fm.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }

    /// Reachability only: write/read/delete a probe item in the plain Keychain service.
    public static func probePlainKeychain() -> Bool {
        let service = "com.smartbalance.zhiyu.plain"
        let account = "smartbalance.compat-probe"
        let payload = Data("probe".utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)

        var add = base
        add[kSecValueData as String] = payload
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            return false
        }

        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let copyStatus = SecItemCopyMatching(query as CFDictionary, &result)
        SecItemDelete(base as CFDictionary)
        guard copyStatus == errSecSuccess, let data = result as? Data, data == payload else {
            return false
        }
        return true
    }

    private func makeCheck(
        _ id: CompatibilityCheckID,
        _ value: (CompatibilityStatus, String)
    ) -> CompatibilityCheck {
        CompatibilityCheck(id: id.rawValue, status: value.0, messageKey: value.1)
    }

    private func macos(_ context: CompatibilityContext) -> (CompatibilityStatus, String) {
        if isVersion(
            context.macOSMajor,
            context.macOSMinor,
            context.macOSPatch,
            atLeast: context.minimumMacOSMajor,
            context.minimumMacOSMinor,
            context.minimumMacOSPatch
        ) {
            return (.ok, "compat.macos.ok")
        }
        return (.failed, "compat.macos.unsupported")
    }

    private func architecture(_ value: CompatibilityArchitecture) -> (CompatibilityStatus, String) {
        switch value {
        case .appleSilicon: return (.ok, "compat.architecture.appleSilicon")
        case .intel: return (.ok, "compat.architecture.intel")
        case .unknown: return (.warning, "compat.architecture.unknown")
        }
    }

    private func notifications(_ state: NotificationAuthorizationState) -> (CompatibilityStatus, String) {
        switch state {
        case .authorized, .provisional:
            return (.ok, "compat.notifications.authorized")
        case .notDetermined:
            return (.warning, "compat.notifications.notDetermined")
        case .denied:
            return (.warning, "compat.notifications.denied")
        case .restricted:
            return (.warning, "compat.notifications.restricted")
        case .unknown:
            return (.warning, "compat.notifications.unknown")
        }
    }

    private func inspectSettings(_ url: URL) -> (
        settings: (CompatibilityStatus, String),
        schema: (CompatibilityStatus, String),
        schemaVersion: Int?
    ) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ((.warning, "compat.settings.missing"), (.warning, "compat.schema.missing"), nil)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return ((.failed, "compat.settings.unreadable"), (.warning, "compat.schema.unreadable"), nil)
        }
        do {
            let outcome = try SettingsMigration.migrate(data: data)
            let schema: (CompatibilityStatus, String)
            if outcome.sourceSchemaVersion == 0 {
                schema = (.ok, "compat.schema.legacy")
            } else {
                schema = (.ok, "compat.schema.ok")
            }
            return ((.ok, "compat.settings.ok"), schema, outcome.document.schemaVersion)
        } catch SettingsMigrationError.unsupportedSchemaVersion(let version) {
            return ((.ok, "compat.settings.ok"), (.failed, "compat.schema.unsupported"), version)
        } catch {
            return ((.failed, "compat.settings.corrupt"), (.warning, "compat.schema.unreadable"), nil)
        }
    }

    private func usageHealth(_ health: UsageStorageHealth?) -> (CompatibilityStatus, String)? {
        guard let health else { return nil }
        switch health {
        case .available:
            return nil
        case .needsRestore:
            return (.warning, "compat.usage.needsRestore")
        case .lastSaveFailed:
            return (.warning, "compat.usage.saveFailed")
        case .loadFailed:
            return (.warning, "compat.usage.unreadable")
        }
    }

    private func inspectUsageHistory(_ url: URL) -> (CompatibilityStatus, String) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (.ok, "compat.usage.missing")
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return (.warning, "compat.usage.unreadable")
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            _ = try decoder.decode(UsageHistoryDocument.self, from: data)
            return (.ok, "compat.usage.ok")
        } catch {
            return (.warning, "compat.usage.corrupt")
        }
    }

    private func isVersion(
        _ major: Int,
        _ minor: Int,
        _ patch: Int,
        atLeast minMajor: Int,
        _ minMinor: Int,
        _ minPatch: Int
    ) -> Bool {
        if major != minMajor { return major > minMajor }
        if minor != minMinor { return minor > minMinor }
        return patch >= minPatch
    }
}
