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

/// 手动检查更新（GitHub Releases；无仓库时回退说明）。
public struct UpdateChecker: Sendable {
    /// 可选：将来接上正式仓库。
    public static let releasesAPI = URL(string: "https://api.github.com/repos/yancyfeng999-star/smartbalance/releases/latest")
    public static let releasesPage = URL(string: "https://github.com/yancyfeng999-star/smartbalance/releases")

    public init() {}

    public func currentVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
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
                    message: "检查失败 HTTP \(code)"
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
            if compareVersion(latest, current) > 0 {
                return UpdateCheckResult(
                    status: .available,
                    currentVersion: current,
                    latestVersion: latest,
                    message: "发现新版本 \(latest)",
                    openURL: html ?? Self.releasesPage
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
                message: "检查失败：\(error.localizedDescription)"
            )
        }
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
