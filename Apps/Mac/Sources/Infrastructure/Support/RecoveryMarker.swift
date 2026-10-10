import Foundation
import Domain

public enum SmartBalanceSupportPaths: Sendable {
    public static var applicationSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SmartBalance", isDirectory: true)
    }
}

public struct RecoveryMarker: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let fileName = "session.marker.json"

    public var schemaVersion: Int
    public var sessionID: String
    public var startedAt: Date
    public var phase: RecoverySessionPhase
    public var processIdentifier: Int32
    public var continuedFromSafeMode: Bool

    public init(
        schemaVersion: Int = RecoveryMarker.currentSchemaVersion,
        sessionID: String = UUID().uuidString,
        startedAt: Date = Date(),
        phase: RecoverySessionPhase = .launching,
        processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier,
        continuedFromSafeMode: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.sessionID = sessionID
        self.startedAt = startedAt
        self.phase = phase
        self.processIdentifier = processIdentifier
        self.continuedFromSafeMode = continuedFromSafeMode
    }
}

public struct RecoveryLedger: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let fileName = "recovery-ledger.json"

    public var schemaVersion: Int
    public var consecutiveUncleanExits: Int
    public var lastUncleanAt: Date?
    public var lastReason: RecoveryReason?

    public static let empty = RecoveryLedger()

    public init(
        schemaVersion: Int = RecoveryLedger.currentSchemaVersion,
        consecutiveUncleanExits: Int = 0,
        lastUncleanAt: Date? = nil,
        lastReason: RecoveryReason? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.consecutiveUncleanExits = consecutiveUncleanExits
        self.lastUncleanAt = lastUncleanAt
        self.lastReason = lastReason
    }
}

public struct UpdateInProgressMarker: Codable, Equatable, Sendable {
    public static let fileName = "update-in-progress.json"

    public var startedAt: Date
    public var destinationAppPath: String

    public init(startedAt: Date = Date(), destinationAppPath: String) {
        self.startedAt = startedAt
        self.destinationAppPath = destinationAppPath
    }
}
