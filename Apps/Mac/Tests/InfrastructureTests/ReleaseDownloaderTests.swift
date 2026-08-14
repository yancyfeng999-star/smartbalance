import XCTest
@testable import Domain
@testable import Infrastructure

final class ReleaseDownloaderTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sb-dl-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testDownloadWritesTemporaryFileAndDoesNotTouchDownloads() async throws {
        let payload = Data("pkg-bytes".utf8)
        let downloader = makeDownloader(transport: FixtureReleaseDownloadTransport(data: payload))
        let temp = try await downloader.downloadToTemporaryFile(
            from: httpsURL,
            fileName: "SmartBalance-0.3.2.pkg",
            expectedSize: Int64(payload.count)
        )
        XCTAssertTrue(temp.path.hasPrefix(tempDir.path))
        XCTAssertEqual(try Data(contentsOf: temp), payload)
        XCTAssertTrue(downloadEntries().isEmpty)
    }

    func testPromoteHappensOnlyAfterCallerValidates() async throws {
        let payload = Data("ok-pkg".utf8)
        let downloader = makeDownloader(transport: FixtureReleaseDownloadTransport(data: payload))
        let temp = try await downloader.downloadToTemporaryFile(
            from: httpsURL,
            fileName: "SmartBalance-0.3.2.pkg"
        )
        XCTAssertTrue(downloadEntries().isEmpty)
        let promoted = try downloader.promoteToDownloads(tempURL: temp, fileName: "SmartBalance-0.3.2.pkg")
        XCTAssertTrue(promoted.path.hasPrefix(downloadsDir.path))
        XCTAssertEqual(try Data(contentsOf: promoted), payload)
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.path))
    }

    func testValidationFailureCleansTemporaryFileAndLeavesDownloadsEmpty() async throws {
        let payload = Data("bad-pkg".utf8)
        let downloader = makeDownloader(transport: FixtureReleaseDownloadTransport(data: payload))
        let temp = try await downloader.downloadToTemporaryFile(
            from: httpsURL,
            fileName: "SmartBalance-0.3.2.pkg"
        )
        let destApp = try seedDestinationApp()
        let settings = try seedSettings()
        let originalSettings = try Data(contentsOf: settings)
        let originalApp = try Data(contentsOf: destApp.appendingPathComponent("Contents/Info.plist"))

        downloader.cleanup(temp)

        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.path))
        XCTAssertTrue(downloadEntries().isEmpty)
        XCTAssertEqual(try Data(contentsOf: settings), originalSettings)
        XCTAssertEqual(try Data(contentsOf: destApp.appendingPathComponent("Contents/Info.plist")), originalApp)
    }

    func testCancelCleansTemporaryFile() async throws {
        let transport = HangUntilCancelledTransport()
        let downloader = makeDownloader(transport: transport)
        let remote = URL(string: "https://github.com/yancyfeng999-star/smartbalance/releases/download/v0.3.2/SmartBalance-0.3.2.pkg")!
        let task = Task {
            try await downloader.downloadToTemporaryFile(from: remote, fileName: "SmartBalance-0.3.2.pkg")
        }
        await transport.waitUntilStarted()
        downloader.cancel()
        do {
            _ = try await task.value
            XCTFail("cancelled download should throw")
        } catch let error as ReleaseDownloadError {
            XCTAssertEqual(error, .cancelled)
        }
        XCTAssertTrue(tempLeftovers().isEmpty)
        XCTAssertTrue(downloadEntries().isEmpty)
    }

    func testTimeoutCleansTemporaryFile() async throws {
        let transport = FixtureReleaseDownloadTransport(error: .timeout)
        let downloader = makeDownloader(transport: transport)
        do {
            _ = try await downloader.downloadToTemporaryFile(from: httpsURL, fileName: "SmartBalance-0.3.2.pkg")
            XCTFail("timeout should throw")
        } catch let error as ReleaseDownloadError {
            XCTAssertEqual(error, .timeout)
        }
        XCTAssertTrue(tempLeftovers().isEmpty)
        XCTAssertTrue(downloadEntries().isEmpty)
    }

    func testInsufficientDiskSpaceDoesNotCreateFiles() async throws {
        let started = CallFlag()
        let transport = FixtureReleaseDownloadTransport(data: Data("x".utf8), onStart: { started.value = true })
        let downloader = ReleaseDownloader(
            transport: transport,
            temporaryDirectory: tempDir,
            downloadsDirectory: downloadsDir,
            availableBytes: { _ in 128 }
        )
        do {
            _ = try await downloader.downloadToTemporaryFile(
                from: httpsURL,
                fileName: "SmartBalance-0.3.2.pkg",
                expectedSize: 50_000_000
            )
            XCTFail("disk space check should throw")
        } catch let error as ReleaseDownloadError {
            XCTAssertEqual(error, .insufficientDiskSpace)
        }
        XCTAssertFalse(started.value)
        XCTAssertTrue(tempLeftovers().isEmpty)
        XCTAssertTrue(downloadEntries().isEmpty)
    }

    func testSizeLimitAbortsAndCleansTemporaryFile() async throws {
        let tooBig = Data(repeating: 0x61, count: 64)
        let downloader = makeDownloader(transport: FixtureReleaseDownloadTransport(data: tooBig))
        do {
            _ = try await downloader.downloadToTemporaryFile(
                from: httpsURL,
                fileName: "SmartBalance-0.3.2.pkg",
                maxBytes: 16
            )
            XCTFail("oversize download should throw")
        } catch let error as ReleaseDownloadError {
            XCTAssertEqual(error, .sizeExceeded)
        }
        XCTAssertTrue(tempLeftovers().isEmpty)
        XCTAssertTrue(downloadEntries().isEmpty)
    }

    func testHTTPURLIsRejected() async throws {
        let downloader = makeDownloader(transport: FixtureReleaseDownloadTransport(data: Data("x".utf8)))
        do {
            _ = try await downloader.downloadToTemporaryFile(
                from: URL(string: "http://example.test/SmartBalance-0.3.2.pkg")!,
                fileName: "SmartBalance-0.3.2.pkg"
            )
            XCTFail("http should throw")
        } catch let error as ReleaseDownloadError {
            XCTAssertEqual(error, .invalidURL)
        }
    }

    private var httpsURL: URL {
        URL(string: "https://github.com/yancyfeng999-star/smartbalance/releases/download/v0.3.2/SmartBalance-0.3.2.pkg")!
    }

    private var tempDir: URL { directory.appendingPathComponent("tmp", isDirectory: true) }
    private var downloadsDir: URL { directory.appendingPathComponent("Downloads", isDirectory: true) }

    private func makeDownloader(transport: any ReleaseDownloadTransport) -> ReleaseDownloader {
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        return ReleaseDownloader(
            transport: transport,
            temporaryDirectory: tempDir,
            downloadsDirectory: downloadsDir,
            availableBytes: { _ in 2_000_000_000 }
        )
    }

    private func downloadEntries() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: downloadsDir, includingPropertiesForKeys: nil)) ?? []
    }

    private func tempLeftovers() -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)) ?? []
        return items.filter { $0.lastPathComponent != ".DS_Store" }
    }

    private func seedDestinationApp() throws -> URL {
        let app = directory.appendingPathComponent("智余.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try Data("original-app".utf8).write(to: contents.appendingPathComponent("Info.plist"))
        return app
    }

    private func seedSettings() throws -> URL {
        let settings = directory.appendingPathComponent("settings.json")
        try Data("{\"accounts\":[1]}".utf8).write(to: settings)
        return settings
    }
}

private final class CallFlag: @unchecked Sendable {
    var value = false
}

struct FixtureReleaseDownloadTransport: ReleaseDownloadTransport, Sendable {
    var data: Data
    var error: ReleaseDownloadError?
    var onStart: (@Sendable () -> Void)?

    init(data: Data = Data(), error: ReleaseDownloadError? = nil, onStart: (@Sendable () -> Void)? = nil) {
        self.data = data
        self.error = error
        self.onStart = onStart
    }

    func download(
        from url: URL,
        to destination: URL,
        maxBytes: Int64,
        onProgress: (@Sendable (Double) -> Void)?,
        isCancelled: @Sendable () -> Bool
    ) async throws -> URL {
        onStart?()
        if let error { throw error }
        if isCancelled() { throw ReleaseDownloadError.cancelled }
        if Int64(data.count) > maxBytes { throw ReleaseDownloadError.sizeExceeded }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination)
        onProgress?(1)
        return destination
    }
}

final class HangUntilCancelledTransport: ReleaseDownloadTransport, @unchecked Sendable {
    private let startedSource = DispatchSemaphore(value: 0)

    func waitUntilStarted() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                _ = self.startedSource.wait(timeout: .now() + 2)
                continuation.resume()
            }
        }
    }

    func download(
        from url: URL,
        to destination: URL,
        maxBytes: Int64,
        onProgress: (@Sendable (Double) -> Void)?,
        isCancelled: @Sendable () -> Bool
    ) async throws -> URL {
        startedSource.signal()
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("partial".utf8).write(to: destination)
        for _ in 0..<200 {
            if isCancelled() { throw ReleaseDownloadError.cancelled }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw ReleaseDownloadError.timeout
    }
}
