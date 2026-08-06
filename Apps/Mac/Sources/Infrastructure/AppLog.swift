import Foundation
import AppKit

/// 简单本地文件日志：~/Library/Logs/SmartBalance/app.log
public enum AppLog {
    private static let lock = NSLock()

    public static var directoryURL: URL {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/SmartBalance", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static var fileURL: URL {
        directoryURL.appendingPathComponent("app.log")
    }

    public static func info(_ message: String, file: String = #fileID, line: Int = #line) {
        write(level: "INFO", message: message, file: file, line: line)
    }

    public static func error(_ message: String, file: String = #fileID, line: Int = #line) {
        write(level: "ERROR", message: message, file: file, line: line)
    }

    public static func write(level: String, message: String, file: String = #fileID, line: Int = #line) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let lineOut = "[\(ts)] [\(level)] \(file):\(line) \(message)\n"
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL
        if let data = lineOut.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    defer { try? handle.close() }
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                }
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    /// 打开日志目录（Finder）。
    @MainActor
    public static func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
}
