import Foundation

public struct DiagnosticOptions: Sendable, Equatable {
    public var includeSanitizedLogs: Bool
    public var maxLogLines: Int
    public var maxLogReadBytes: Int

    public static let defaultMaxLogLines = 200
    public static let defaultMaxLogReadBytes = 256 * 1024

    public static let `default` = DiagnosticOptions()

    public init(
        includeSanitizedLogs: Bool = true,
        maxLogLines: Int = DiagnosticOptions.defaultMaxLogLines,
        maxLogReadBytes: Int = DiagnosticOptions.defaultMaxLogReadBytes
    ) {
        self.includeSanitizedLogs = includeSanitizedLogs
        self.maxLogLines = max(1, maxLogLines)
        self.maxLogReadBytes = max(4_096, maxLogReadBytes)
    }
}
