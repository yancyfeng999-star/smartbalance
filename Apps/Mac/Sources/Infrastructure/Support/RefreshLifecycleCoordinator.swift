import Foundation
import Domain

@MainActor
public protocol RefreshDelayScheduling: AnyObject {
    var pendingWorkCount: Int { get }
    var pendingIDs: [String] { get }
    func schedule(id: String, after delay: TimeInterval, execute: @escaping @MainActor () -> Void)
    func cancel(id: String)
    func cancelAll()
}

@MainActor
public final class TaskRefreshScheduler: RefreshDelayScheduling {
    private var tasks: [String: Task<Void, Never>] = [:]

    public init() {}

    public var pendingWorkCount: Int { tasks.count }
    public var pendingIDs: [String] { Array(tasks.keys) }

    public func schedule(id: String, after delay: TimeInterval, execute: @escaping @MainActor () -> Void) {
        tasks[id]?.cancel()
        tasks[id] = Task { @MainActor [weak self] in
            let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
            if nanoseconds > 0 {
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            guard !Task.isCancelled else { return }
            self?.tasks[id] = nil
            execute()
        }
    }

    public func cancel(id: String) {
        tasks[id]?.cancel()
        tasks[id] = nil
    }

    public func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
    }
}

public final class ControllableRefreshScheduler: @unchecked Sendable {
    private struct Job {
        var token: UUID
        var id: String
        var fireAt: Date
        var execute: @MainActor () -> Void
    }

    private let clock: ControllableRefreshClock
    private let lock = NSLock()
    private var jobs: [Job] = []

    public init(clock: ControllableRefreshClock) {
        self.clock = clock
    }

    public var pendingWorkCount: Int {
        lock.lock(); defer { lock.unlock() }
        return jobs.count
    }

    public var pendingIDs: [String] {
        lock.lock(); defer { lock.unlock() }
        return jobs.map(\.id)
    }

    public func schedule(id: String, after delay: TimeInterval, execute: @escaping @MainActor () -> Void) {
        lock.lock()
        jobs.removeAll { $0.id == id }
        jobs.append(
            Job(
                token: UUID(),
                id: id,
                fireAt: clock.now.addingTimeInterval(max(0, delay)),
                execute: execute
            )
        )
        lock.unlock()
    }

    public func cancel(id: String) {
        lock.lock()
        jobs.removeAll { $0.id == id }
        lock.unlock()
    }

    public func cancelAll() {
        lock.lock()
        jobs.removeAll()
        lock.unlock()
    }

    @MainActor
    public func advance(by interval: TimeInterval) {
        let target = clock.now.addingTimeInterval(interval)
        while true {
            lock.lock()
            let next = jobs.min(by: { $0.fireAt < $1.fireAt })
            guard let next, next.fireAt <= target else {
                lock.unlock()
                clock.set(target)
                return
            }
            jobs.removeAll { $0.token == next.token }
            lock.unlock()
            clock.set(next.fireAt)
            next.execute()
        }
    }

    @MainActor
    public func runDue() {
        advance(by: 0)
    }
}

extension ControllableRefreshScheduler: RefreshDelayScheduling {}

public actor RefreshConcurrencyLimiter {
    private let limit: Int
    private var inFlight = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    public private(set) var peak = 0

    public init(limit: Int = RefreshFetchLimits.maxConcurrentAccounts) {
        self.limit = max(1, limit)
    }

    public func withPermit<T: Sendable>(_ body: @Sendable () async -> T) async -> T {
        await acquire()
        defer { release() }
        return await body()
    }

    private func acquire() async {
        if inFlight < limit {
            inFlight += 1
            peak = max(peak, inFlight)
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        if waiters.isEmpty {
            inFlight = max(0, inFlight - 1)
            return
        }
        waiters.removeFirst().resume()
    }
}

@MainActor
public protocol AppSleepWakeHandling: AnyObject {
    func handleSystemWillSleep()
    func handleSystemDidWake()
}

@MainActor
public final class AppLifecycleCenter {
    public static let shared = AppLifecycleCenter()
    public weak var handler: (any AppSleepWakeHandling)?

    public func noteWillSleep() {
        handler?.handleSystemWillSleep()
    }

    public func noteDidWake() {
        handler?.handleSystemDidWake()
    }

    public func resetForTests() {
        handler = nil
    }
}

@MainActor
public final class RefreshLifecycleCoordinator {
    public static let initialRefreshDelay: TimeInterval = 0.4
    public static let wakeDebounceInterval: TimeInterval = 2.0
    public static let intervalTimerID = "timer-interval"
    public static let pendingRefreshID = "pending-refresh"

    public private(set) var intervalTimerCount = 0
    public private(set) var scheduledRefreshCount = 0
    public private(set) var isSleeping = false
    public private(set) var lastScheduledTrigger: RefreshTrigger?

    public var onScheduleRefresh: ((RefreshTrigger) -> Void)?
    public var onCancelInFlight: ((RefreshCancelReason) -> Void)?

    private let scheduler: any RefreshDelayScheduling
    private var allowsRefresh: Bool
    private var intervalSecs: Int
    private var pendingTrigger: RefreshTrigger?

    public init(
        clock: any RefreshClock = SystemRefreshClock(),
        scheduler: any RefreshDelayScheduling,
        allowsRefresh: Bool = true,
        intervalSecs: Int = 900,
        wakeDebounce: TimeInterval = RefreshLifecycleCoordinator.wakeDebounceInterval,
        initialDelay: TimeInterval = RefreshLifecycleCoordinator.initialRefreshDelay
    ) {
        _ = clock
        self.scheduler = scheduler
        self.allowsRefresh = allowsRefresh
        self.intervalSecs = intervalSecs
        _ = wakeDebounce
        _ = initialDelay
    }

    public func updatePolicy(allowsRefresh: Bool, intervalSecs: Int) {
        self.allowsRefresh = allowsRefresh
        self.intervalSecs = intervalSecs
        if !allowsRefresh {
            stop()
        }
    }

    public func start() {
        stop()
        guard allowsRefresh else { return }
        schedulePending(trigger: .interval, delay: Self.initialRefreshDelay)
        if intervalSecs > 0 {
            startIntervalTimer(firstDelay: Self.initialRefreshDelay + TimeInterval(intervalSecs))
        }
    }

    public func stop() {
        scheduler.cancel(id: Self.intervalTimerID)
        scheduler.cancel(id: Self.pendingRefreshID)
        intervalTimerCount = 0
        pendingTrigger = nil
    }

    public func handle(_ event: RefreshLifecycleEvent, prefersRefresh: Bool? = nil) {
        if let reason = RefreshLifecyclePolicy.cancelReason(for: event) {
            if event == .willSleep {
                isSleeping = true
                scheduler.cancel(id: Self.intervalTimerID)
                scheduler.cancel(id: Self.pendingRefreshID)
                intervalTimerCount = 0
                pendingTrigger = nil
            }
            onCancelInFlight?(reason)
            return
        }

        switch event {
        case .didWake:
            isSleeping = false
            guard allowsRefresh else { return }
            schedulePending(trigger: .interval, delay: Self.wakeDebounceInterval)
            if intervalSecs > 0 {
                startIntervalTimer(firstDelay: TimeInterval(intervalSecs))
            }
        case .menuAppear:
            guard allowsRefresh else { return }
            let shouldRefresh = prefersRefresh ?? RefreshLifecyclePolicy.shouldScheduleRefresh(for: event)
            if shouldRefresh {
                schedulePending(trigger: .menuOpen, delay: 0)
            }
        case .intervalTick:
            guard allowsRefresh else { return }
            schedulePending(trigger: .interval, delay: 0)
        case .windowPinned, .pageSwitch, .notificationStateChange,
             .userCancel, .windowClosed, .applicationDidResignActive,
             .themeIdentityRebuild, .willSleep:
            break
        }
    }

    private func schedulePending(trigger: RefreshTrigger, delay: TimeInterval) {
        guard allowsRefresh else { return }
        if pendingTrigger != nil {
            return
        }
        pendingTrigger = trigger
        scheduler.schedule(id: Self.pendingRefreshID, after: delay) { [weak self] in
            self?.firePending()
        }
    }

    private func firePending() {
        guard let trigger = pendingTrigger else { return }
        pendingTrigger = nil
        scheduledRefreshCount += 1
        lastScheduledTrigger = trigger
        onScheduleRefresh?(trigger)
    }

    private func startIntervalTimer(firstDelay: TimeInterval) {
        guard allowsRefresh, intervalSecs > 0, !isSleeping else {
            scheduler.cancel(id: Self.intervalTimerID)
            intervalTimerCount = 0
            return
        }
        intervalTimerCount = 1
        scheduler.schedule(id: Self.intervalTimerID, after: firstDelay) { [weak self] in
            self?.handleIntervalFire()
        }
    }

    private func handleIntervalFire() {
        guard allowsRefresh, intervalSecs > 0, !isSleeping else {
            intervalTimerCount = 0
            return
        }
        startIntervalTimer(firstDelay: TimeInterval(intervalSecs))
        schedulePending(trigger: .interval, delay: 0)
    }
}
