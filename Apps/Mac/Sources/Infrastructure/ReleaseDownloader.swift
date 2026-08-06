import Foundation

/// 下载 GitHub Release 安装包到「下载」文件夹（对齐智额 ReleaseDownloader，非静默安装）。
public final class ReleaseDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var progressHandler: (@Sendable (Double) -> Void)?
    private var continuation: CheckedContinuation<URL, Error>?
    private var destinationFileName: String = "SmartBalance-update.zip"
    private var session: URLSession?

    public override init() {
        super.init()
    }

    public enum DownloadError: Error, LocalizedError, Sendable {
        case invalidURL
        case network(String)

        public var errorDescription: String? {
            switch self {
            case .invalidURL: "无效下载地址"
            case .network(let s): s
            }
        }
    }

    /// 下载到 `~/Downloads/<fileName>`。
    public func download(
        from url: URL,
        fileName: String? = nil,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            throw DownloadError.invalidURL
        }
        destinationFileName = Self.safeFileName(fileName ?? url.lastPathComponent)
        progressHandler = onProgress

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
            session.downloadTask(with: request).resume()
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesExpectedToWrite > 0 {
            let fraction = min(1, max(0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
            progressHandler?(fraction)
        } else if totalBytesWritten > 0 {
            progressHandler?(min(0.95, Double(totalBytesWritten) / (12 * 1024 * 1024)))
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let name = destinationFileName
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dest = downloads.appendingPathComponent(name, isDirectory: false)
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.copyItem(at: location, to: dest)
            progressHandler?(1)
            let cont = continuation
            continuation = nil
            cont?.resume(returning: dest)
        } catch {
            let cont = continuation
            continuation = nil
            cont?.resume(throwing: DownloadError.network(error.localizedDescription))
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            let cont = continuation
            continuation = nil
            cont?.resume(throwing: DownloadError.network(error.localizedDescription))
        }
        session.finishTasksAndInvalidate()
        self.session = nil
    }

    private static func safeFileName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "SmartBalance-update.zip" }
        let base = (trimmed as NSString).lastPathComponent
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let cleaned = String(base.unicodeScalars.map { allowed.contains($0) ? Character($0) : Character("_") })
        return cleaned.isEmpty ? "SmartBalance-update.zip" : cleaned
    }
}
