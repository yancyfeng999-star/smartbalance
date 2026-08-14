import Foundation
import AppKit
import Domain

/// 本地文件日志：~/Library/Logs/SmartBalance/app.log
/// 写入前脱敏；按大小轮转（只 rename）。文件 IO 在专用队列，不占用调用线程。
public enum AppLog {
    public enum ErrorCategory: String, Sendable {
        case settings
        case usage
        case network
        case smtp
        case keychain
        case update
        case backup
        case refresh
        case notification
        case filesystem
        case unknown
    }

    public static let defaultMaxFileSizeBytes: Int64 = 512 * 1024
    public static let defaultMaxRotatedFiles = 3
    public static let diagnosticLineLimit = DiagnosticOptions.defaultMaxLogLines

    private static let queueKey = DispatchSpecificKey<UInt8>()
    private static let ioQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "com.smartbalance.applog", qos: .utility)
        queue.setSpecific(key: queueKey, value: 1)
        return queue
    }()

    nonisolated(unsafe) public static var directoryOverride: URL?
    nonisolated(unsafe) public static var maxFileSizeBytesOverride: Int64?
    nonisolated(unsafe) public static var maxRotatedFilesOverride: Int?
    nonisolated(unsafe) public static var fileIOThreadObserverForTests: (() -> Void)?
    nonisolated(unsafe) public static var writeShouldFailForTests = false
    public static let filePermission = 0o600

    public static var directoryURL: URL {
        if let directoryOverride {
            try? FileManager.default.createDirectory(at: directoryOverride, withIntermediateDirectories: true)
            return directoryOverride
        }
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/SmartBalance", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static var fileURL: URL {
        directoryURL.appendingPathComponent("app.log")
    }

    public static func info(_ message: String, file: String = #fileID, line: Int = #line) {
        write(level: "INFO", message: message, category: .unknown, event: nil, file: file, line: line)
    }

    public static func error(_ message: String, file: String = #fileID, line: Int = #line) {
        write(level: "ERROR", message: message, category: .unknown, event: nil, file: file, line: line)
    }

    public static func error(
        _ message: String,
        category: ErrorCategory,
        event: String? = nil,
        file: String = #fileID,
        line: Int = #line
    ) {
        write(level: "ERROR", message: message, category: category, event: event, file: file, line: line)
    }

    public static func write(level: String, message: String, file: String = #fileID, line: Int = #line) {
        write(level: level, message: message, category: .unknown, event: nil, file: file, line: line)
    }

    public static func write(
        level: String,
        message: String,
        category: ErrorCategory,
        event: String?,
        file: String,
        line: Int
    ) {
        let redacted = PrivacyRedactor.redact(message)
        let ts = ISO8601DateFormatter().string(from: Date())
        let eventPart = event.map { " event=\($0)" } ?? ""
        let lineOut = "[\(ts)] [\(level)] [\(category.rawValue)] \(file):\(line)\(eventPart) \(redacted)\n"
        ioQueue.async {
            fileIOThreadObserverForTests?()
            if writeShouldFailForTests { return }
            rotateIfNeededOnQueue()
            appendOnQueue(lineOut)
        }
    }

    public static func tailLines(
        maxLines: Int = diagnosticLineLimit,
        maxBytes: Int = DiagnosticOptions.defaultMaxLogReadBytes
    ) -> [String] {
        onIOQueue { tailLinesOnQueue(from: fileURL, maxLines: maxLines, maxBytes: maxBytes) }
    }

    public static func tailLines(from url: URL, maxLines: Int, maxBytes: Int) -> [String] {
        onIOQueue { tailLinesOnQueue(from: url, maxLines: maxLines, maxBytes: maxBytes) }
    }

    public static func resetForTests() {
        maxFileSizeBytesOverride = nil
        maxRotatedFilesOverride = nil
        fileIOThreadObserverForTests = nil
        writeShouldFailForTests = false
    }

    public static func flushForTests() {
        ioQueue.sync {}
    }

    /// 打开日志目录（Finder）。
    @MainActor
    public static func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private static func onIOQueue<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return work()
        }
        return ioQueue.sync(execute: work)
    }

    private static func rotateIfNeededOnQueue() {
        let maxSize = maxFileSizeBytesOverride ?? defaultMaxFileSizeBytes
        let maxRotated = max(1, maxRotatedFilesOverride ?? defaultMaxRotatedFiles)
        let url = fileURL
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber,
              size.int64Value >= maxSize
        else { return }

        let fm = FileManager.default
        let dir = directoryURL
        let oldest = dir.appendingPathComponent("app.log.\(maxRotated)")
        if fm.fileExists(atPath: oldest.path) {
            try? fm.removeItem(at: oldest)
        }
        if maxRotated >= 2 {
            for index in stride(from: maxRotated - 1, through: 1, by: -1) {
                let source = dir.appendingPathComponent("app.log.\(index)")
                let destination = dir.appendingPathComponent("app.log.\(index + 1)")
                guard fm.fileExists(atPath: source.path) else { continue }
                try? fm.removeItem(at: destination)
                try? fm.moveItem(at: source, to: destination)
            }
        }
        let first = dir.appendingPathComponent("app.log.1")
        try? fm.removeItem(at: first)
        try? fm.moveItem(at: url, to: first)
        applyFilePermissions(first)
        for index in 1...maxRotated {
            applyFilePermissions(dir.appendingPathComponent("app.log.\(index)"))
        }
    }

    private static func appendOnQueue(_ lineOut: String) {
        let url = fileURL
        guard let data = lineOut.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                do {
                    try handle.write(contentsOf: data)
                } catch {
                    return
                }
            }
        } else {
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                return
            }
        }
        applyFilePermissions(url)
    }

    private static func applyFilePermissions(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.setAttributes(
            [.posixPermissions: filePermission],
            ofItemAtPath: url.path
        )
    }

    private static func tailLinesOnQueue(from url: URL, maxLines: Int, maxBytes: Int) -> [String] {
        guard FileManager.default.fileExists(atPath: url.path),
              let handle = try? FileHandle(forReadingFrom: url)
        else { return [] }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let cap = UInt64(max(4_096, maxBytes))
        let readSize = min(cap, size)
        do {
            try handle.seek(toOffset: size - readSize)
        } catch {
            return []
        }
        let data = (try? handle.readToEnd()) ?? Data()
        guard var text = String(data: data, encoding: .utf8) else { return [] }
        if size > readSize, let newline = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: newline)...])
        }
        let parts = text.split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
        return Array(parts.suffix(max(1, maxLines)))
    }
}
