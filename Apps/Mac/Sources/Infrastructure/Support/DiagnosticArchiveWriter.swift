import Foundation
import Domain

public struct DiagnosticArchiveWriter: Sendable {
    public init() {}

    public func writeJSON(_ report: DiagnosticReport, to url: URL) throws {
        let data = PrivacyRedactor.redact(try DiagnosticReport.encode(report))
        try writeRestricted(data, to: url)
    }

    public func writeText(_ report: DiagnosticReport, to url: URL) throws {
        let text = PrivacyRedactor.redact(Self.textSummary(report))
        try writeRestricted(Data(text.utf8), to: url)
    }

    public func writeZip(_ report: DiagnosticReport, to url: URL) throws {
        let json = PrivacyRedactor.redact(try DiagnosticReport.encode(report))
        let text = Data(PrivacyRedactor.redact(Self.textSummary(report)).utf8)
        let archive = try StoredZipWriter.encode(entries: [
            (name: "smartbalance-diagnostics.json", data: json),
            (name: "smartbalance-diagnostics.txt", data: text),
        ])
        try writeRestricted(archive, to: url)
    }

    public func writePackage(
        _ report: DiagnosticReport,
        to directory: URL
    ) throws -> (json: URL, text: URL, zip: URL) {
        let json = directory.appendingPathComponent("smartbalance-diagnostics.json")
        let text = directory.appendingPathComponent("smartbalance-diagnostics.txt")
        let zip = directory.appendingPathComponent("smartbalance-diagnostics.zip")
        try writeJSON(report, to: json)
        try writeText(report, to: text)
        try writeZip(report, to: zip)
        return (json, text, zip)
    }

    public static func textSummary(_ report: DiagnosticReport) -> String {
        var lines: [String] = []
        lines.append("EXCLUDED FIELDS")
        for field in report.excludedFields {
            lines.append("- \(field)")
        }
        lines.append("")
        lines.append("SUMMARY")
        lines.append("appVersion: \(report.appVersion)")
        lines.append("build: \(report.build)")
        lines.append("osVersion: \(report.osVersion)")
        lines.append("architecture: \(report.architecture)")
        lines.append("launchMode: \(report.launchMode)")
        if let schema = report.schemaVersion {
            lines.append("schemaVersion: \(schema)")
        }
        lines.append("keychain: \(report.keychainStatus.rawValue)")
        lines.append("notifications: \(report.notificationAuthorization)")
        lines.append("refresh: \(report.refresh.state) \(report.refresh.succeededCount)/\(report.refresh.failedCount)")
        lines.append("providers: \(report.providers.count)")
        lines.append("usageRecords: \(report.usage.recordCount)")
        lines.append("migration: \(report.lastMigrationResult)")
        lines.append("backup: \(report.lastBackupResult)")
        lines.append("restore: \(report.lastRestoreResult)")
        lines.append("")
        lines.append("CHECKS")
        for check in report.checks {
            let detail = check.redactedDetail.map { " \($0)" } ?? ""
            lines.append("[\(check.status.rawValue)] \(check.id) \(check.detailKey)\(detail)")
        }
        if !report.sanitizedLogLines.isEmpty {
            lines.append("")
            lines.append("SANITIZED LOG TAIL")
            lines.append(contentsOf: report.sanitizedLogLines)
        }
        return lines.joined(separator: "\n")
    }

    private func writeRestricted(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }
}

enum StoredZipWriter {
    static func encode(entries: [(name: String, data: Data)]) throws -> Data {
        var locals = Data()
        var central = Data()
        var offset: UInt32 = 0
        for entry in entries {
            let nameData = Data(entry.name.utf8)
            let crc = CRC32.hash(entry.data)
            let size = UInt32(entry.data.count)
            var local = Data()
            local.appendUInt32(0x04034b50)
            local.appendUInt16(20)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt32(crc)
            local.appendUInt32(size)
            local.appendUInt32(size)
            local.appendUInt16(UInt16(nameData.count))
            local.appendUInt16(0)
            local.append(nameData)
            local.append(entry.data)
            locals.append(local)

            var dir = Data()
            dir.appendUInt32(0x02014b50)
            dir.appendUInt16(20)
            dir.appendUInt16(20)
            dir.appendUInt16(0)
            dir.appendUInt16(0)
            dir.appendUInt16(0)
            dir.appendUInt16(0)
            dir.appendUInt32(crc)
            dir.appendUInt32(size)
            dir.appendUInt32(size)
            dir.appendUInt16(UInt16(nameData.count))
            dir.appendUInt16(0)
            dir.appendUInt16(0)
            dir.appendUInt16(0)
            dir.appendUInt16(0)
            dir.appendUInt32(0)
            dir.appendUInt32(offset)
            dir.append(nameData)
            central.append(dir)
            offset += UInt32(local.count)
        }

        var eocd = Data()
        eocd.appendUInt32(0x06054b50)
        eocd.appendUInt16(0)
        eocd.appendUInt16(0)
        eocd.appendUInt16(UInt16(entries.count))
        eocd.appendUInt16(UInt16(entries.count))
        eocd.appendUInt32(UInt32(central.count))
        eocd.appendUInt32(UInt32(locals.count))
        eocd.appendUInt16(0)
        return locals + central + eocd
    }
}

private enum CRC32 {
    private static let table: [UInt32] = {
        (0..<256).map { index -> UInt32 in
            var crc = UInt32(index)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
            return crc
        }
    }()

    static func hash(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let idx = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[idx] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
