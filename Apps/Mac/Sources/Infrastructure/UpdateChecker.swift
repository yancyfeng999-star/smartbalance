import Foundation
import Domain

public struct UpdateCheckResult: Sendable, Equatable {
    public enum Status: String, Sendable {
        case upToDate
        case available
        case unknown
        case failed
    }

    public var status: Status
    public var currentVersion: String
    public var latestVersion: String?
    public var message: String
    public var messageKey: String
    public var messageArguments: [String]
    /// Release 页
    public var openURL: URL?
    /// 安装包下载（优先 .pkg）
    public var downloadURL: URL?
    public var details: UpdateReleaseDetails?

    public init(
        status: Status,
        currentVersion: String,
        latestVersion: String? = nil,
        message: String,
        messageKey: String = "",
        messageArguments: [String] = [],
        openURL: URL? = nil,
        downloadURL: URL? = nil,
        details: UpdateReleaseDetails? = nil
    ) {
        self.status = status
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.message = message
        self.messageKey = messageKey
        self.messageArguments = messageArguments
        self.openURL = openURL
        self.downloadURL = downloadURL
        self.details = details
    }
}

/// 检查更新（公开 GitHub Releases，无 Sparkle）。
/// P1：只检查并返回版本说明，不自动下载或安装。
public struct UpdateChecker: Sendable {
    public static let githubOwner = "yancyfeng999-star"
    public static let githubRepo = "smartbalance"

    public static var releasesAPI: URL? {
        URL(string: "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest")
    }

    public static var releasesPage: URL? {
        URL(string: "https://github.com/\(githubOwner)/\(githubRepo)/releases")
    }

    /// 国内访问 api.github.com 偶发慢，请求超时放宽；失败时再试一次。
    private static let requestTimeout: TimeInterval = 30
    private static let maxAttempts = 2

    private let client: any HTTPClient
    private let currentVersionOverride: String?

    public init(client: (any HTTPClient)? = nil, currentVersion: String? = nil) {
        self.client = client ?? UpdateAPIClient.makeDefault()
        self.currentVersionOverride = currentVersion
    }

    public func currentVersion() -> String {
        if let currentVersionOverride, !currentVersionOverride.isEmpty {
            return currentVersionOverride
        }
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0"
    }

    public func check() async -> UpdateCheckResult {
        let current = currentVersion()
        guard let api = Self.releasesAPI else {
            return UpdateCheckResult(
                status: .unknown,
                currentVersion: current,
                message: "local build \(current)",
                messageKey: "update.check.local_build",
                messageArguments: [current]
            )
        }

        var lastError: Error?
        for attempt in 1...Self.maxAttempts {
            do {
                return try await fetchLatest(api: api, current: current)
            } catch {
                lastError = error
                AppLog.info("Update check attempt \(attempt)/\(Self.maxAttempts) failed: \(error.localizedDescription)")
                if attempt < Self.maxAttempts {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                }
            }
        }

        let detail = friendlyNetworkError(lastError)
        return UpdateCheckResult(
            status: .failed,
            currentVersion: current,
            message: "check failed: \(detail)",
            messageKey: "update.check.failed",
            openURL: Self.releasesPage
        )
    }

    private func fetchLatest(api: URL, current: String) async throws -> UpdateCheckResult {
        var request = URLRequest(url: api)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SmartBalance (update-check)", forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = Self.requestTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await client.data(for: request)
        let code = response.statusCode
        if code == 404 {
            return UpdateCheckResult(
                status: .unknown,
                currentVersion: current,
                message: "no public release for \(current)",
                messageKey: "update.check.no_release",
                messageArguments: [current],
                openURL: Self.releasesPage
            )
        }
        guard (200...299).contains(code) else {
            return UpdateCheckResult(
                status: .failed,
                currentVersion: current,
                message: "HTTP \(code)",
                messageKey: "update.check.http_failed",
                messageArguments: ["\(code)"],
                openURL: Self.releasesPage
            )
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            json["tag_name"] is String
        else {
            return UpdateCheckResult(
                status: .failed,
                currentVersion: current,
                message: "unable to parse release",
                messageKey: "update.check.parse_failed",
                openURL: Self.releasesPage
            )
        }
        var result = makeResult(from: json, current: current)
        if result.status == .available, let sumsURL = result.details?.checksumManifestURL {
            result.details?.checksumManifestText = await fetchChecksumManifest(sumsURL)
        }
        return result
    }

    public func makeResult(from releaseJSON: [String: Any], current: String) -> UpdateCheckResult {
        guard let tag = releaseJSON["tag_name"] as? String else {
            return UpdateCheckResult(
                status: .failed,
                currentVersion: current,
                message: "unable to parse release",
                messageKey: "update.check.parse_failed",
                openURL: Self.releasesPage
            )
        }
        let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let html = (releaseJSON["html_url"] as? String).flatMap(URL.init(string:))
        let package = preferredPackageAsset(from: releaseJSON)
        let notesRaw = releaseJSON["body"] as? String ?? ""
        let notes = UpdateReleaseNotes.plainTextSummary(notesRaw)
        let publishedAt = Self.parsePublishedAt(releaseJSON["published_at"] as? String)
        let details = UpdateReleaseDetails(
            currentVersion: current,
            targetVersion: latest,
            publishedAt: publishedAt,
            releaseNotesPlainText: notes,
            asset: package,
            minimumMacOS: UpdateMinimumOSParser.parse(fromReleaseNotes: notesRaw),
            releasePageURL: html ?? Self.releasesPage,
            checksumManifestURL: checksumManifestURL(from: releaseJSON)
        )

        if UpdateVersion.parse(latest) == nil {
            return UpdateCheckResult(
                status: .failed,
                currentVersion: current,
                latestVersion: latest,
                message: "malformed version \(latest)",
                messageKey: "update.check.parse_failed",
                openURL: html ?? Self.releasesPage,
                details: details
            )
        }

        if let comparison = UpdateVersion.compare(latest, current), comparison > 0 {
            return UpdateCheckResult(
                status: .available,
                currentVersion: current,
                latestVersion: latest,
                message: "New version \(latest) is available",
                messageKey: "update.check.available",
                messageArguments: [latest],
                openURL: html ?? Self.releasesPage,
                downloadURL: package?.downloadURL,
                details: details
            )
        }
        return UpdateCheckResult(
            status: .upToDate,
            currentVersion: current,
            latestVersion: latest,
            message: "Already up to date \(current)",
            messageKey: "update.check.up_to_date",
            messageArguments: [current],
            openURL: html ?? Self.releasesPage,
            details: details
        )
    }

    private func fetchChecksumManifest(_ url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.setValue("SmartBalance (update-check)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = Self.requestTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await client.data(for: request)
            guard (200...299).contains(response.statusCode) else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private static func parsePublishedAt(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: raw) { return date }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: raw)
    }

    private func friendlyNetworkError(_ error: Error?) -> String {
        guard let error else { return "未知网络错误" }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorTimedOut:
                return "连接 GitHub 超时（网络不稳或被墙），请稍后重试或浏览器打开发布页"
            case NSURLErrorNotConnectedToInternet:
                return "无网络连接"
            case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                return "无法解析 GitHub 域名"
            case NSURLErrorNetworkConnectionLost:
                return "网络中断"
            default:
                break
            }
        }
        let desc = error.localizedDescription
        if desc.contains("超时") || desc.lowercased().contains("timed out") {
            return "连接 GitHub 超时，请稍后重试或浏览器打开发布页"
        }
        return desc
    }

    /// 优先 pkg → dmg；同类型优先 SmartBalance。不再把 zip 当作安装包。
    func preferredPackageURL(from releaseJSON: [String: Any]) -> URL? {
        preferredPackageAsset(from: releaseJSON)?.downloadURL
    }

    func preferredPackageAsset(from releaseJSON: [String: Any]) -> UpdateAsset? {
        guard let assets = releaseJSON["assets"] as? [[String: Any]] else { return nil }
        let parsed: [UpdateAsset] = assets.compactMap { asset in
            guard
                let name = asset["name"] as? String,
                UpdateAssetName.isAllowed(name),
                let urlStr = asset["browser_download_url"] as? String,
                let url = URL(string: urlStr),
                let kind = UpdateAssetKind(rawValue: URL(fileURLWithPath: name).pathExtension.lowercased())
            else { return nil }
            return UpdateAsset(
                fileName: name,
                downloadURL: url,
                byteSize: Self.int64(asset["size"]) ?? 0,
                kind: kind
            )
        }
        return parsed.min { lhs, rhs in
            score(lhs) < score(rhs)
        }
    }

    func checksumManifestURL(from releaseJSON: [String: Any]) -> URL? {
        guard let assets = releaseJSON["assets"] as? [[String: Any]] else { return nil }
        for asset in assets {
            guard
                let name = asset["name"] as? String,
                name.lowercased() == "sha256sums.txt",
                let urlStr = asset["browser_download_url"] as? String,
                let url = URL(string: urlStr)
            else { continue }
            return url
        }
        return nil
    }

    private func score(_ asset: UpdateAsset) -> Int {
        let brandedEnglish = asset.fileName.lowercased().contains("smartbalance")
        switch asset.kind {
        case .pkg: return brandedEnglish ? 0 : 1
        case .dmg: return brandedEnglish ? 10 : 11
        }
    }

    private static func int64(_ any: Any?) -> Int64? {
        if let value = any as? Int64 { return value }
        if let value = any as? Int { return Int64(value) }
        if let value = any as? NSNumber { return value.int64Value }
        return nil
    }
}

private struct UpdateAPIClient: HTTPClient {
    let session: URLSession

    static func makeDefault() -> UpdateAPIClient {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 45
        config.waitsForConnectivity = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        return UpdateAPIClient(session: URLSession(configuration: config))
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
