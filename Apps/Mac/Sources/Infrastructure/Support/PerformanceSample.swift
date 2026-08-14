import Foundation

public enum PerformanceSampleResult: Sendable, Equatable {
    case success
    case failure
    case cancel
}

public struct PerformanceCounters: Sendable, Equatable {
    public var successCount: Int
    public var failureCount: Int
    public var cancelCount: Int
    public var accountSuccessCount: Int
    public var accountFailureCount: Int
    public var totalDuration: TimeInterval
    public var lastDuration: TimeInterval
    public var peakConcurrency: Int
    public var sampleCount: Int

    public init(
        successCount: Int = 0,
        failureCount: Int = 0,
        cancelCount: Int = 0,
        accountSuccessCount: Int = 0,
        accountFailureCount: Int = 0,
        totalDuration: TimeInterval = 0,
        lastDuration: TimeInterval = 0,
        peakConcurrency: Int = 0,
        sampleCount: Int = 0
    ) {
        self.successCount = successCount
        self.failureCount = failureCount
        self.cancelCount = cancelCount
        self.accountSuccessCount = accountSuccessCount
        self.accountFailureCount = accountFailureCount
        self.totalDuration = totalDuration
        self.lastDuration = lastDuration
        self.peakConcurrency = peakConcurrency
        self.sampleCount = sampleCount
    }
}

/// Local aggregate metrics only. Never stores URLs, bodies, Keychain, or credentials.
public final class PerformanceSample: @unchecked Sendable {
    private let lock = NSLock()
    private var counters = PerformanceCounters()

    public init() {}

    public func record(
        duration: TimeInterval,
        result: PerformanceSampleResult,
        accountSuccesses: Int = 0,
        accountFailures: Int = 0
    ) {
        lock.lock()
        defer { lock.unlock() }
        switch result {
        case .success:
            counters.successCount += 1
        case .failure:
            counters.failureCount += 1
        case .cancel:
            counters.cancelCount += 1
        }
        counters.accountSuccessCount += max(0, accountSuccesses)
        counters.accountFailureCount += max(0, accountFailures)
        counters.totalDuration += duration
        counters.lastDuration = duration
        counters.sampleCount += 1
    }

    public func recordConcurrency(_ value: Int) {
        lock.lock()
        defer { lock.unlock() }
        counters.peakConcurrency = max(counters.peakConcurrency, value)
    }

    public func snapshot() -> PerformanceCounters {
        lock.lock()
        defer { lock.unlock() }
        return counters
    }

    public func debugFieldNames() -> [String] {
        [
            "successCount",
            "failureCount",
            "cancelCount",
            "accountSuccessCount",
            "accountFailureCount",
            "totalDuration",
            "lastDuration",
            "peakConcurrency",
            "sampleCount",
        ]
    }

    public func debugDescriptionText() -> String {
        let counters = snapshot()
        return "success=\(counters.successCount) failure=\(counters.failureCount) cancel=\(counters.cancelCount) duration=\(counters.totalDuration) peak=\(counters.peakConcurrency) samples=\(counters.sampleCount)"
    }
}
