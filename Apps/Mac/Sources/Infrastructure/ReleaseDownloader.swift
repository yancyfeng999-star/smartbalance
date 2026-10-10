import Foundation
import Domain

public enum ReleaseDownloadError: Error, Equatable, LocalizedError, Sendable {
    case invalidURL
    case cancelled
    case timeout
    case insufficientDiskSpace
    case sizeExceeded
    case network(String)
    case validationFailed

    public var localizationKey: String {
        switch self {
        case .invalidURL: return "update.error.urlNotHTTPS"
        case .cancelled: return "update.error.cancelled"
        case .timeout: return "update.error.timeout"
        case .insufficientDiskSpace: return "update.error.insufficientDiskSpace"
        case .sizeExceeded: return "update.error.sizeExceedsLimit"
        case .network: return "update.error.network"
        case .validationFailed: return "update.error.validationFailed"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "invalid download URL"
        case .cancelled: return "download cancelled"
        case .timeout: return "download timed out"
        case .insufficientDiskSpace: return "not enough disk space"
        case .sizeExceeded: return "download exceeded size limit"
        case .network(let message): return message
        case .validationFailed: return "package validation failed"
        }
    }
}

public protocol ReleaseDownloadTransport: Sendable {
    func download(
        from url: URL,
        to destination: URL,
        maxBytes: Int64,
        onProgress: (@Sendable (Double) -> Void)?,
        isCancelled: @Sendable () -> Bool
    ) async throws -> URL
}

/// Downloads a GitHub Release package to a temporary file. Promote to Downloads only after validation.
public final class ReleaseDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let state = ReleaseDownloaderState()
    private var progressHandler: (@Sendable (Double) -> Void)?
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    private var expectedMaxBytes: Int64 = UpdateSafetyLimits.maxAssetBytes
    private var stagingFile: URL?

    private let transport: (any ReleaseDownloadTransport)?
    private let temporaryDirectory: URL
    private let downloadsDirectory: URL
    private let availableBytes: (@Sendable (URL) -> Int64?)?

    public override convenience init() {
        self.init(transport: nil, temporaryDirectory: nil, downloadsDirectory: nil, availableBytes: nil)
    }

    public init(
        transport: (any ReleaseDownloadTransport)? = nil,
        temporaryDirectory: URL? = nil,
        downloadsDirectory: URL? = nil,
        availableBytes: (@Sendable (URL) -> Int64?)? = nil
    ) {
        self.transport = transport
        self.temporaryDirectory = temporaryDirectory ?? FileManager.default.temporaryDirectory
        self.downloadsDirectory = downloadsDirectory
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.availableBytes = availableBytes
        super.init()
    }

    public func cancel() {
        state.cancelled = true
        downloadTask?.cancel()
    }

    public func downloadToTemporaryFile(
        from url: URL,
        fileName: String? = nil,
        expectedSize: Int64? = nil,
        maxBytes: Int64 = UpdateSafetyLimits.maxAssetBytes,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        state.cancelled = false

        guard url.scheme?.lowercased() == "https" else {
            throw ReleaseDownloadError.invalidURL
        }
        if let expectedSize, expectedSize > maxBytes {
            throw ReleaseDownloadError.sizeExceeded
        }

        let needed = max(expectedSize ?? 0, 1) + UpdateSafetyLimits.diskReserveBytes
        if let available = availableBytes?(temporaryDirectory), available < needed {
            throw ReleaseDownloadError.insufficientDiskSpace
        } else if availableBytes == nil, expectedSize != nil {
            if let values = try? temporaryDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
               let capacity = values.volumeAvailableCapacityForImportantUsage,
               capacity < needed
            {
                throw ReleaseDownloadError.insufficientDiskSpace
            }
        }

        let work = temporaryDirectory.appendingPathComponent("sb-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let dest = work.appendingPathComponent(Self.safeFileName(fileName ?? url.lastPathComponent))

        do {
            if isCancelled { throw ReleaseDownloadError.cancelled }
            let finished: URL
            if let transport {
                finished = try await transport.download(
                    from: url,
                    to: dest,
                    maxBytes: maxBytes,
                    onProgress: onProgress,
                    isCancelled: { [weak self] in self?.isCancelled ?? true }
                )
            } else {
                finished = try await downloadWithURLSession(
                    from: url,
                    to: dest,
                    maxBytes: maxBytes,
                    onProgress: onProgress
                )
            }
            if isCancelled {
                cleanup(work)
                throw ReleaseDownloadError.cancelled
            }
            let size = (try? FileManager.default.attributesOfItem(atPath: finished.path)[.size] as? NSNumber)?.int64Value ?? 0
            if size <= 0 {
                cleanup(work)
                throw ReleaseDownloadError.sizeExceeded
            }
            if size > maxBytes {
                cleanup(work)
                throw ReleaseDownloadError.sizeExceeded
            }
            return finished
        } catch let error as ReleaseDownloadError {
            cleanup(work)
            throw error
        } catch let error as URLError where error.code == .cancelled || error.code == .timedOut {
            cleanup(work)
            throw error.code == .timedOut ? ReleaseDownloadError.timeout : ReleaseDownloadError.cancelled
        } catch {
            cleanup(work)
            if isCancelled { throw ReleaseDownloadError.cancelled }
            throw ReleaseDownloadError.network(error.localizedDescription)
        }
    }

    public func promoteToDownloads(tempURL: URL, fileName: String? = nil) throws -> URL {
        try FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        let name = Self.safeFileName(fileName ?? tempURL.lastPathComponent)
        let dest = downloadsDirectory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)
        cleanup(tempURL.deletingLastPathComponent())
        return dest
    }

    public func cleanup(_ url: URL) {
        let fm = FileManager.default
        var target = url
        if fm.fileExists(atPath: target.path) {
            if !target.hasDirectoryPath,
               target.deletingLastPathComponent().lastPathComponent.hasPrefix("sb-update-")
            {
                target = target.deletingLastPathComponent()
            }
            try? fm.removeItem(at: target)
        }
    }

    /// Legacy entry: still downloads to a temp file only. Callers must validate before promoting.
    public func download(
        from url: URL,
        fileName: String? = nil,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        try await downloadToTemporaryFile(from: url, fileName: fileName, onProgress: onProgress)
    }

    private var isCancelled: Bool { state.cancelled }

    private func downloadWithURLSession(
        from url: URL,
        to dest: URL,
        maxBytes: Int64,
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws -> URL {
        progressHandler = onProgress
        expectedMaxBytes = maxBytes
        stagingFile = dest

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("SmartBalance (release-download)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 300

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300
            config.timeoutIntervalForResource = 600
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            self.session = session
            let task = session.downloadTask(with: request)
            self.downloadTask = task
            task.resume()
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesWritten > expectedMaxBytes || (totalBytesExpectedToWrite > expectedMaxBytes && totalBytesExpectedToWrite > 0) {
            downloadTask.cancel()
            finish(.failure(ReleaseDownloadError.sizeExceeded))
            return
        }
        if totalBytesExpectedToWrite > 0 {
            progressHandler?(min(1, max(0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))))
        } else if totalBytesWritten > 0 {
            progressHandler?(min(0.95, Double(totalBytesWritten) / Double(expectedMaxBytes)))
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let dest = stagingFile else {
            finish(.failure(ReleaseDownloadError.network("missing destination")))
            return
        }
        do {
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: location, to: dest)
            progressHandler?(1)
            finish(.success(dest))
        } catch {
            finish(.failure(ReleaseDownloadError.network(error.localizedDescription)))
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            if (error as? URLError)?.code == .cancelled || isCancelled {
                finish(.failure(ReleaseDownloadError.cancelled))
            } else if (error as? URLError)?.code == .timedOut {
                finish(.failure(ReleaseDownloadError.timeout))
            } else {
                finish(.failure(ReleaseDownloadError.network(error.localizedDescription)))
            }
        }
        session.finishTasksAndInvalidate()
        self.session = nil
        self.downloadTask = nil
    }

    private func finish(_ result: Result<URL, Error>) {
        let cont = continuation
        continuation = nil
        switch result {
        case .success(let url):
            cont?.resume(returning: url)
        case .failure(let error):
            cont?.resume(throwing: error)
        }
    }

    private static func safeFileName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "SmartBalance-update.pkg" }
        let base = URL(fileURLWithPath: trimmed).lastPathComponent
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-智余"))
        let cleaned = String(base.unicodeScalars.map { allowed.contains($0) ? Character($0) : Character("_") })
        return cleaned.isEmpty ? "SmartBalance-update.pkg" : cleaned
    }
}

private final class ReleaseDownloaderState: @unchecked Sendable {
    private let lock = NSLock()
    private var _cancelled = false

    var cancelled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _cancelled
        }
        set {
            lock.lock()
            _cancelled = newValue
            lock.unlock()
        }
    }
}
