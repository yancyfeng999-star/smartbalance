import Foundation

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
    /// Release 页
    public var openURL: URL?
    /// 安装包下载（优先 .pkg，有则一点更新自动静默安装）
    public var downloadURL: URL?

    public init(
        status: Status,
        currentVersion: String,
        latestVersion: String? = nil,
        message: String,
        openURL: URL? = nil,
        downloadURL: URL? = nil
    ) {
        self.status = status
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.message = message
        self.openURL = openURL
        self.downloadURL = downloadURL
    }
}

/// 检查更新（公开 GitHub Releases，无 Sparkle）。
/// 有新版本时自动下载 **pkg** → 静默解包覆盖 → 重启，中间不弹窗。
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

    public init() {}

    public func currentVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0"
    }

    public func check() async -> UpdateCheckResult {
        let current = currentVersion()
        guard let api = Self.releasesAPI else {
            return UpdateCheckResult(
                status: .unknown,
                currentVersion: current,
                message: "当前 \(current)（本地构建）"
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
            message: "检查失败：\(detail) · 可点下方打开 GitHub 手动下载",
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

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = Self.requestTimeout
        config.timeoutIntervalForResource = Self.requestTimeout + 15
        config.waitsForConnectivity = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 {
            return UpdateCheckResult(
                status: .unknown,
                currentVersion: current,
                message: "当前 \(current) · 暂无公开 Release",
                openURL: Self.releasesPage
            )
        }
        guard (200...299).contains(code) else {
            return UpdateCheckResult(
                status: .failed,
                currentVersion: current,
                message: "检查失败 HTTP \(code)",
                openURL: Self.releasesPage
            )
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tag = json["tag_name"] as? String
        else {
            return UpdateCheckResult(
                status: .failed,
                currentVersion: current,
                message: "无法解析版本信息",
                openURL: Self.releasesPage
            )
        }
        let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let html = (json["html_url"] as? String).flatMap(URL.init(string:))
        let package = preferredPackageURL(from: json)

        if compareVersion(latest, current) > 0 {
            return UpdateCheckResult(
                status: .available,
                currentVersion: current,
                latestVersion: latest,
                message: "发现新版本 \(latest)，正在下载安装…",
                openURL: html ?? Self.releasesPage,
                downloadURL: package
            )
        }
        return UpdateCheckResult(
            status: .upToDate,
            currentVersion: current,
            latestVersion: latest,
            message: "已是最新 \(current)",
            openURL: html ?? Self.releasesPage
        )
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

    /// 优先 pkg（静默装）→ dmg → zip；同类型优先 SmartBalance 英文名。
    func preferredPackageURL(from releaseJSON: [String: Any]) -> URL? {
        guard let assets = releaseJSON["assets"] as? [[String: Any]] else { return nil }
        let namesAndURLs: [(String, URL)] = assets.compactMap { asset in
            guard
                let name = asset["name"] as? String,
                let urlStr = asset["browser_download_url"] as? String,
                let url = URL(string: urlStr)
            else { return nil }
            return (name, url)
        }
        let ranked = namesAndURLs.compactMap { name, url -> (Int, URL)? in
            let n = name.lowercased()
            let branded = n.contains("smartbalance") || name.contains("智余")
            let score: Int
            if n.hasSuffix(".pkg") {
                // SmartBalance-*.pkg 路径最稳
                if n.contains("smartbalance") { score = 0 }
                else if branded { score = 1 }
                else { score = 2 }
            } else if n.hasSuffix(".dmg") {
                score = branded ? 10 : 11
            } else if n.hasSuffix(".zip") {
                score = branded ? 20 : 21
            } else {
                return nil
            }
            return (score, url)
        }
        return ranked.sorted { $0.0 < $1.0 }.first?.1
    }

    /// 简易 semver 比较：a > b → 1
    private func compareVersion(_ a: String, _ b: String) -> Int {
        let pa = a.split(separator: ".").compactMap { Int($0) }
        let pb = b.split(separator: ".").compactMap { Int($0) }
        let n = max(pa.count, pb.count)
        for i in 0..<n {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y ? 1 : -1 }
        }
        return 0
    }
}
