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
    /// 优先：Release 页；有资产时指向 zip 下载
    public var openURL: URL?

    public init(
        status: Status,
        currentVersion: String,
        latestVersion: String? = nil,
        message: String,
        openURL: URL? = nil
    ) {
        self.status = status
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.message = message
        self.openURL = openURL
    }
}

/// 检查更新（公开 GitHub Releases，与智额同思路：无 Sparkle 服务端）。
/// 用户从 Release 下载 zip 安装；「检查更新」打开下载/发布页。
public struct UpdateChecker: Sendable {
    public static let githubOwner = "yancyfeng999-star"
    public static let githubRepo = "smartbalance"

    public static var releasesAPI: URL? {
        URL(string: "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest")
    }

    public static var releasesPage: URL? {
        URL(string: "https://github.com/\(githubOwner)/\(githubRepo)/releases")
    }

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

        var request = URLRequest(url: api)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SmartBalance (update-check)", forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
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
                    message: "无法解析版本信息"
                )
            }
            let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let html = (json["html_url"] as? String).flatMap(URL.init(string:))
            let download = preferredZipURL(from: json) ?? html ?? Self.releasesPage

            if compareVersion(latest, current) > 0 {
                return UpdateCheckResult(
                    status: .available,
                    currentVersion: current,
                    latestVersion: latest,
                    message: "发现新版本 \(latest) · 点「打开发布页」下载",
                    openURL: download
                )
            }
            return UpdateCheckResult(
                status: .upToDate,
                currentVersion: current,
                latestVersion: latest,
                message: "已是最新 \(current)",
                openURL: html ?? Self.releasesPage
            )
        } catch {
            return UpdateCheckResult(
                status: .failed,
                currentVersion: current,
                message: "检查失败：\(error.localizedDescription)",
                openURL: Self.releasesPage
            )
        }
    }

    /// 优先 SmartBalance-*-macOS.zip / 智余*.zip
    private func preferredZipURL(from releaseJSON: [String: Any]) -> URL? {
        guard let assets = releaseJSON["assets"] as? [[String: Any]] else { return nil }
        let namesAndURLs: [(String, URL)] = assets.compactMap { asset in
            guard
                let name = asset["name"] as? String,
                let urlStr = asset["browser_download_url"] as? String,
                let url = URL(string: urlStr)
            else { return nil }
            return (name, url)
        }
        let preferred = namesAndURLs.first { name, _ in
            let n = name.lowercased()
            return n.contains("smartbalance") && n.hasSuffix(".zip")
        }
        ?? namesAndURLs.first { name, _ in
            let n = name.lowercased()
            return n.hasSuffix(".zip") && (n.contains("macos") || n.contains("mac") || n.contains("智余"))
        }
        ?? namesAndURLs.first { $0.0.lowercased().hasSuffix(".zip") }
        return preferred?.1
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
