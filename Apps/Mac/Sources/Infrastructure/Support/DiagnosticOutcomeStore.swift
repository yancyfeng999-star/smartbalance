import Foundation
import Domain

public struct DiagnosticOutcomeStore: Sendable {
    public let fileURL: URL

    public init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent(DiagnosticOutcomeLedger.fileName)
    }

    public func load() -> DiagnosticOutcomeLedger {
        guard let data = try? Data(contentsOf: fileURL),
              let ledger = try? SettingsDocument.makeDecoder().decode(DiagnosticOutcomeLedger.self, from: data)
        else {
            return .empty
        }
        return ledger
    }

    public func save(_ ledger: DiagnosticOutcomeLedger) throws {
        let data = try SettingsDocument.makeEncoder().encode(ledger)
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    public func record(
        _ kind: DiagnosticOutcomeKind,
        result: DiagnosticOutcomeResult,
        at: Date = Date()
    ) {
        let next = load().updated(kind, result: result, at: at)
        try? save(next)
    }
}
