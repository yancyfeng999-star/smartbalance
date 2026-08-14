import Foundation

public protocol RefreshClock: Sendable {
    var now: Date { get }
}

public struct SystemRefreshClock: RefreshClock {
    public init() {}

    public var now: Date { Date() }
}

public final class ControllableRefreshClock: @unchecked Sendable, RefreshClock {
    private let lock = NSLock()
    private var instant: Date

    public init(_ now: Date = Date(timeIntervalSince1970: 1_787_000_000)) {
        instant = now
    }

    public var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return instant
    }

    public func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        instant = instant.addingTimeInterval(interval)
    }

    public func set(_ date: Date) {
        lock.lock()
        defer { lock.unlock() }
        instant = date
    }
}
