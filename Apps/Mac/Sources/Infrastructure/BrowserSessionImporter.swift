import Foundation
import Domain
import CommonCrypto

/// 从本机 Chrome / Edge 读取已登录控制台的 Cookie，供浏览器钱包渠道一键导入。
///
/// - Important: 全部逻辑可重入后台线程；禁止在 MainActor 上同步调用。
public enum BrowserSessionImporter: Sendable {
    public struct Credential: Sendable, Equatable {
        public var secret: String
        public var userId: String?
        public var source: String
    }

    public enum ImportError: Error, LocalizedError, Sendable {
        case unsupportedKind
        case browserNotFound
        case browserAccessDenied
        case browserReadFailed
        case invalidBrowserDirectory
        case keychainDenied(String)
        case cookieNotFound(String)
        case decryptFailed
        case timedOut(String)

        public var errorDescription: String? {
            switch self {
            case .unsupportedKind:
                return "当前平台不支持浏览器导入"
            case .browserNotFound:
                return "未找到 Chrome / Edge。请安装并登录控制台后重试"
            case .browserAccessDenied:
                return "macOS 未允许智余读取浏览器数据。请点「授权目录并重新连接」，在系统窗口中选择 Chrome 或 Edge 数据目录后重试。这是目录权限问题，不代表网站未登录"
            case .browserReadFailed:
                return "浏览器数据读取失败，请重试或手动填写 Cookie（这不代表未登录）"
            case .invalidBrowserDirectory:
                return "请选择 Chrome / Edge 数据目录，或其中的 Default / Profile 用户目录"
            case .keychainDenied(let s):
                return "无法读取浏览器钥匙串：\(s)。若弹出权限请点「允许」后重试"
            case .cookieNotFound(let s):
                return s
            case .decryptFailed:
                return "Cookie 解密失败。请退出 Chrome 后再试，或手动粘贴 Cookie"
            case .timedOut(let s):
                return s
            }
        }
    }

    /// 异步导入（始终在非主线程执行）。
    public static func importSessionAsync(for kind: ProviderKind, browserDirectory: URL? = nil) async throws -> Credential {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    cont.resume(returning: try importSession(for: kind, browserDirectory: browserDirectory))
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    /// 同步导入；仅应在后台队列调用。
    public static func importSession(for kind: ProviderKind, browserDirectory: URL? = nil) throws -> Credential {
        switch kind {
        case .mimo: return try importMiMo(browserDirectory: browserDirectory)
        case .minimax: return try importMiniMax(browserDirectory: browserDirectory)
        case .apinebula: return try importApinebula(browserDirectory: browserDirectory)
        case .bytebroad: return try importBytebroad(browserDirectory: browserDirectory)
        default: throw ImportError.unsupportedKind
        }
    }

    // MARK: - Platforms

    private static func importMiMo(browserDirectory: URL?) throws -> Credential {
        let cookies = try loadCookies(
            hostNeedles: ["xiaomimimo"],
            names: ["api-platform_serviceToken", "userId"],
            browserDirectory: browserDirectory
        )
        return try miMoCredential(from: cookies)
    }

    static func miMoCredential(from cookies: [CookieRow]) throws -> Credential {
        guard let tokenRow = cookies.first(where: { $0.name == "api-platform_serviceToken" && !$0.value.isEmpty }) else {
            throw ImportError.cookieNotFound(
                "未找到 MiMo 登录态。请先在 Chrome 登录 https://platform.xiaomimimo.com/console/balance 后再导入"
            )
        }
        guard let userId = cookies.first(where: {
            $0.name == "userId" && $0.browserName == tokenRow.browserName && $0.profileID == tokenRow.profileID
        })?.value, !userId.isEmpty else {
            throw ImportError.cookieNotFound("找到 serviceToken，但缺少 userId。请确认已登录控制台")
        }
        return Credential(secret: tokenRow.value, userId: userId, source: tokenRow.browserName)
    }

    private static func importBytebroad(browserDirectory: URL?) throws -> Credential {
        try bytebroadCredential(from: loadCookies(
            hostNeedles: ["token.bytebroad.com.cn"], names: ["session"], browserDirectory: browserDirectory
        ))
    }

    static func bytebroadCredential(from cookies: [CookieRow]) throws -> Credential {
        guard let row = cookies.first(where: {
            $0.host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased() == "token.bytebroad.com.cn"
                && $0.name == "session" && !$0.value.isEmpty
        }) else {
            throw ImportError.cookieNotFound("未找到 Bytebroad 登录态。请打开官网登录，完成后点击「重新连接」")
        }
        guard let uid = SessionCookieParser.extractNewAPISessionUserId(fromSession: row.value) else {
            throw ImportError.cookieNotFound("无法识别 Bytebroad 会话账号。请打开官网刷新或登录后重新连接")
        }
        return Credential(secret: row.value, userId: uid, source: row.browserName)
    }

    private static func importMiniMax(browserDirectory: URL?) throws -> Credential {
        let cookies = try loadCookies(
            hostNeedles: ["minimax.cn", "minimaxi", "minimax.io"],
            names: ["_token", "minimax_group_id_v2"],
            browserDirectory: browserDirectory
        )
        let currentDomainCookies = cookies.filter { $0.host.contains("minimax.cn") }
        let activeProfile = currentDomainCookies.first?.profileID
        let preferredCookies = activeProfile.map { profile in
            currentDomainCookies.filter { $0.profileID == profile }
        } ?? currentDomainCookies
        let token = preferredCookies.first(where: { $0.name == "_token" })?.value
            ?? cookies.first(where: { $0.name == "_token" })?.value
        let groupId = preferredCookies.first(where: { $0.name == "minimax_group_id_v2" })?.value
            ?? cookies.first(where: { $0.name == "minimax_group_id_v2" })?.value
        guard let token, !token.isEmpty else {
            throw ImportError.cookieNotFound(
                "未找到 MiniMax 登录态。请先在 Chrome 登录 https://platform.minimax.cn/console/recharge-records 后再导入"
            )
        }
        guard let groupId, !groupId.isEmpty else {
            throw ImportError.cookieNotFound("找到 _token，但缺少 minimax_group_id_v2。请在控制台刷新后再试")
        }
        let secret = "_token=\(token); minimax_group_id_v2=\(groupId)"
        return Credential(secret: secret, userId: groupId, source: cookies.first?.browserName ?? "Chrome")
    }

    private static func importApinebula(browserDirectory: URL?) throws -> Credential {
        // 当前控制台在 .com；.ai 仅作旧域名后备，避免选到已过期旧会话。
        let cookies = try loadCookies(
            hostNeedles: ["apinebula.com", "apinebula.ai", "apinebula"],
            names: ["session"],
            browserDirectory: browserDirectory
        )
        let session =
            cookies.first(where: { $0.name == "session" && $0.host.contains("apinebula.com") })?.value
            ?? cookies.first(where: { $0.name == "session" })?.value
        guard let session, !session.isEmpty else {
            throw ImportError.cookieNotFound(
                "未找到 apinebula 登录态。请先用 Chrome 打开并登录 https://apinebula.com/zh/console/topup 后再导入"
            )
        }
        guard let userId = SessionCookieParser.extractNewAPIUserId(fromSession: session), !userId.isEmpty else {
            throw ImportError.cookieNotFound(
                "已找到 session，但解析不到用户 ID。请在 Chrome 打开 apinebula.com 控制台刷新后再导入"
            )
        }
        return Credential(
            secret: session,
            userId: userId,
            source: cookies.first?.browserName ?? "Chrome"
        )
    }

    // MARK: - Cookie load

    struct CookieRow: Sendable {
        var host: String
        var name: String
        var value: String
        var browserName: String
        var profileID: String
        var lastAccess: Int64
    }

    private static func loadCookies(hostNeedles: [String], names: [String], browserDirectory: URL?) throws -> [CookieRow] {
        let home = NSHomeDirectory()
        var directoryReadError: ImportError?
        let candidates = try discoverBrowserCookieCandidates(
            home: home, selectedDirectory: browserDirectory, onReadError: { directoryReadError = $0 }
        )

        var sawDB = false
        var lastKeyError: String?
        var cachedKey: [String: Data] = [:]
        var attemptedKeychainServices: Set<String> = []
        var allRows: [CookieRow] = []
        var lastReadError: ImportError? = directoryReadError

        for c in candidates {
            do {
                _ = try FileManager.default.attributesOfItem(atPath: c.path)
            } catch {
                if isMissingFile(error) { continue }
                lastReadError = isAccessDenied(error) ? .browserAccessDenied : .browserReadFailed
                continue
            }
            sawDB = true

            let key: Data
            if let k = cachedKey[c.service] {
                key = k
            } else {
                // 一个浏览器的所有 profile 共用同一条 Safe Storage；失败后不要为每个 profile 重复弹窗。
                guard attemptedKeychainServices.insert(c.service).inserted else { continue }
                do {
                    key = try chromeEncryptionKey(service: c.service, account: c.account)
                    cachedKey[c.service] = key
                } catch {
                    lastKeyError = "钥匙串访问失败"
                    AppLog.error("Browser keychain access failed · service=\(c.service)")
                    continue
                }
            }

            do {
                let rows = try readCookieDB(
                    path: c.path,
                    key: key,
                    hostNeedles: hostNeedles,
                    names: names,
                    browserName: c.name,
                    profileID: c.profileID
                )
                allRows.append(contentsOf: rows)
            } catch {
                lastReadError = isAccessDenied(error) ? .browserAccessDenied : (error as? ImportError ?? .browserReadFailed)
                AppLog.error("Browser cookie read failed · browser=\(c.name) profile=\(c.profileID)")
            }
        }

        if !allRows.isEmpty {
            return allRows.sorted { $0.lastAccess > $1.lastAccess }
        }
        if let lastReadError { throw lastReadError }
        if !sawDB { throw ImportError.browserNotFound }
        if let lastKeyError { throw ImportError.keychainDenied(lastKeyError) }
        return []
    }

    private static func readCookieDB(
        path: String,
        key: Data,
        hostNeedles: [String],
        names: [String],
        browserName: String,
        profileID: String
    ) throws -> [CookieRow] {
        // 复制 Cookies + WAL，避免 Chrome 打开时锁库/半截读
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sb-cookie-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let baseName = URL(fileURLWithPath: path).lastPathComponent
        let dest = tmpDir.appendingPathComponent(baseName)
        try copyIfExists(path, to: dest.path)
        try copyIfExists(path + "-wal", to: dest.path + "-wal")
        try copyIfExists(path + "-shm", to: dest.path + "-shm")

        let like = hostNeedles
            .map { "host_key LIKE '%\($0.replacingOccurrences(of: "'", with: "''"))%'" }
            .joined(separator: " OR ")
        let nameList = names
            .map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" }
            .joined(separator: ",")

        // 用 unit separator 拼接，避免 cookie 值里的特殊字符搞乱解析
        let sql = """
        .mode list
        .separator '|'
        SELECT host_key, name, hex(encrypted_value), last_access_utc, IFNULL(value,'')
        FROM cookies
        WHERE (\(like))
          AND name IN (\(nameList))
          AND (expires_utc = 0 OR expires_utc > (strftime('%s','now') + 11644473600) * 1000000)
        ORDER BY last_access_utc DESC
        LIMIT 80;
        """

        let data = try runProcess(
            executable: "/usr/bin/sqlite3",
            arguments: [dest.path],
            stdin: sql,
            timeoutSeconds: 5
        )
        let text = String(data: data, encoding: .utf8) ?? ""

        var rows: [CookieRow] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: "|", maxSplits: 4, omittingEmptySubsequences: false)
            guard parts.count >= 5 else { continue }
            let host = String(parts[0])
            let name = String(parts[1])
            let hex = String(parts[2])
            let lastAccess = Int64(parts[3]) ?? 0
            let plainCol = String(parts[4])

            let value: String
            if !plainCol.isEmpty {
                value = plainCol
            } else if let enc = Data(hexString: hex), let dec = decryptChromeV10(enc, key: key) {
                value = dec
            } else {
                continue
            }
            guard !value.isEmpty else { continue }
            rows.append(
                CookieRow(
                    host: host,
                    name: name,
                    value: value,
                    browserName: browserName,
                    profileID: profileID,
                    lastAccess: lastAccess
                )
            )
        }
        return rows
    }

    private static func copyIfExists(_ src: String, to dst: String) throws {
        do {
            try FileManager.default.copyItem(atPath: src, toPath: dst)
        } catch {
            if !isMissingFile(error) { throw error }
        }
    }

    /// 带超时 + 并发读管道，避免 stdout 塞满导致进程死锁。
    private static func runProcess(
        executable: String,
        arguments: [String],
        stdin: String? = nil,
        timeoutSeconds: TimeInterval
    ) throws -> Data {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        if let stdin {
            let inPipe = Pipe()
            proc.standardInput = inPipe
            try proc.run()
            inPipe.fileHandleForWriting.write(Data(stdin.utf8))
            try? inPipe.fileHandleForWriting.close()
        } else {
            try proc.run()
        }

        let box = ProcessOutputBox()
        let outHandle = outPipe.fileHandleForReading
        let errHandle = errPipe.fileHandleForReading

        // 并发读 stdout/stderr，防止 pipe 缓冲区塞满死锁
        let q = DispatchQueue(label: "com.smartbalance.process-io", attributes: .concurrent)
        q.async { box.appendOut(outHandle.readDataToEndOfFile()) }
        q.async { box.appendErr(errHandle.readDataToEndOfFile()) }

        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            proc.waitUntilExit()
            group.leave()
        }

        if group.wait(timeout: .now() + timeoutSeconds) == .timedOut {
            proc.terminate()
            // 再等极短时间后强杀
            usleep(100_000)
            if proc.isRunning {
                kill(proc.processIdentifier, SIGKILL)
            }
            throw ImportError.timedOut(
                "读取浏览器超时（\(Int(timeoutSeconds))s）。请完全退出 Chrome 后重试，或改用手动粘贴 Cookie"
            )
        }

        // 等管道读完
        usleep(50_000)
        if proc.terminationStatus != 0 {
            throw ImportError.browserReadFailed
        }
        return box.out
    }

    // MARK: - Crypto

    private static func chromeEncryptionKey(service: String, account: String) throws -> Data {
        let data: Data
        do {
            data = try runProcess(
                executable: "/usr/bin/security",
                arguments: ["find-generic-password", "-w", "-s", service, "-a", account],
                timeoutSeconds: 8
            )
        } catch is ImportError {
            throw ImportError.keychainDenied("钥匙串访问失败")
        } catch {
            throw ImportError.keychainDenied("钥匙串访问失败")
        }
        let password = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if password.isEmpty {
            throw ImportError.keychainDenied("钥匙串无返回。请在弹窗中点「允许」后重试")
        }

        let salt = Data("saltysalt".utf8)
        var derived = Data(count: 16)
        let status = derived.withUnsafeMutableBytes { derivedBytes in
            password.withCString { passPtr in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passPtr,
                        password.utf8.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        1003,
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        16
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw ImportError.decryptFailed }
        return derived
    }

    static func browserCookieCandidates(
        home: String,
        selectedDirectory: URL? = nil,
        listDirectory: (String) throws -> [String] = FileManager.default.contentsOfDirectory(atPath:)
    ) throws -> [(name: String, path: String, service: String, account: String, profileID: String)] {
        try discoverBrowserCookieCandidates(home: home, selectedDirectory: selectedDirectory,
            onReadError: nil, listDirectory: listDirectory)
    }

    private static func discoverBrowserCookieCandidates(
        home: String,
        selectedDirectory: URL? = nil,
        onReadError: ((ImportError) -> Void)?,
        listDirectory: (String) throws -> [String] = FileManager.default.contentsOfDirectory(atPath:)
    ) throws -> [(name: String, path: String, service: String, account: String, profileID: String)] {

        func profileCookiePaths(root: String) throws -> [(profileID: String, path: String)] {
            let names: [String]
            do {
                names = try listDirectory(root)
            } catch {
                if isMissingFile(error) { return [] }
                throw isAccessDenied(error) ? ImportError.browserAccessDenied : ImportError.browserReadFailed
            }
            let profiles = names
                .filter { $0 == "Default" || $0.hasPrefix("Profile ") }
                .sorted { lhs, rhs in
                    if lhs == "Default" { return true }
                    if rhs == "Default" { return false }
                    return lhs.localizedStandardCompare(rhs) == .orderedAscending
                }
            return profiles.map { (profileID: $0, path: root + "/\($0)/Cookies") }
        }

        let chromeRoot = home + "/Library/Application Support/Google/Chrome"
        let edgeRoot = home + "/Library/Application Support/Microsoft Edge"
        let selectedPath = selectedDirectory?.standardizedFileURL.path
        func paths(in root: String) throws -> [(profileID: String, path: String)] {
            guard let selectedPath else { return try profileCookiePaths(root: root) }
            if selectedPath == root { return try profileCookiePaths(root: root) }
            let url = URL(fileURLWithPath: selectedPath)
            let profile = url.lastPathComponent
            if url.deletingLastPathComponent().path == root,
               profile == "Default" || profile.hasPrefix("Profile ") {
                return [(profileID: profile, path: selectedPath + "/Cookies")]
            }
            return []
        }
        if let selectedPath {
            let url = URL(fileURLWithPath: selectedPath)
            let roots = [chromeRoot, edgeRoot]
            let profile = url.lastPathComponent
            guard roots.contains(selectedPath)
                || (roots.contains(url.deletingLastPathComponent().path)
                    && (profile == "Default" || profile.hasPrefix("Profile "))) else {
                throw ImportError.invalidBrowserDirectory
            }
        }
        var discoveryError: ImportError?
        func availablePaths(in root: String) -> [(profileID: String, path: String)] {
            do { return try paths(in: root) }
            catch {
                let issue = error as? ImportError ?? .browserReadFailed
                discoveryError = discoveryError ?? issue
                onReadError?(issue)
                return []
            }
        }
        let chrome = availablePaths(in: chromeRoot).map {
            (
                name: "Chrome",
                path: $0.path,
                service: "Chrome Safe Storage",
                account: "Chrome",
                profileID: $0.profileID
            )
        }
        let edge = availablePaths(in: edgeRoot).map {
            (
                name: "Edge",
                path: $0.path,
                service: "Microsoft Edge Safe Storage",
                account: "Microsoft Edge",
                profileID: $0.profileID
            )
        }
        let result = chrome + edge
        if result.isEmpty, let discoveryError { throw discoveryError }
        return result
    }

    static func isAccessDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == CocoaError.fileReadNoPermission.rawValue { return true }
        if nsError.domain == NSPOSIXErrorDomain && [Int(EPERM), Int(EACCES)].contains(nsError.code) { return true }
        return (nsError.userInfo[NSUnderlyingErrorKey] as? Error).map(isAccessDenied) ?? false
    }

    private static func isMissingFile(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           [CocoaError.fileReadNoSuchFile.rawValue, CocoaError.fileNoSuchFile.rawValue].contains(nsError.code) { return true }
        return nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOENT)
    }

    private static func decryptChromeV10(_ encrypted: Data, key: Data) -> String? {
        guard encrypted.count > 3 else { return nil }
        let prefix = encrypted.prefix(3)
        guard prefix == Data("v10".utf8) || prefix == Data("v11".utf8) else {
            return String(data: encrypted, encoding: .utf8)
        }
        let cipherData = Data(encrypted.dropFirst(3))
        let iv = Data(repeating: UInt8(ascii: " "), count: 16)
        let outCapacity = cipherData.count + kCCBlockSizeAES128
        var out = Data(count: outCapacity)
        var outLen = 0
        let status: CCCryptorStatus = out.withUnsafeMutableBytes { outBytes in
            cipherData.withUnsafeBytes { cipherBytes in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, key.count,
                            ivBytes.baseAddress,
                            cipherBytes.baseAddress, cipherData.count,
                            outBytes.baseAddress, outCapacity,
                            &outLen
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        var plain = out.prefix(outLen)
        if plain.count > 32 {
            let tail = plain.dropFirst(32)
            let printable = tail.filter { ($0 >= 32 && $0 < 127) || $0 == 9 || $0 == 10 || $0 == 13 }.count
            if Double(printable) / Double(max(tail.count, 1)) > 0.85 {
                plain = tail
            }
        }
        var s = String(data: Data(plain), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if s.count >= 2, s.first == "\"", s.last == "\"" {
            s = String(s.dropFirst().dropLast())
        }
        return s.isEmpty ? nil : s
    }
}

/// 线程安全收集进程输出。
private final class ProcessOutputBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _out = Data()
    private var _err = Data()
    var out: Data { lock.lock(); defer { lock.unlock() }; return _out }
    var err: Data { lock.lock(); defer { lock.unlock() }; return _err }
    func appendOut(_ d: Data) { lock.lock(); _out.append(d); lock.unlock() }
    func appendErr(_ d: Data) { lock.lock(); _err.append(d); lock.unlock() }
}

private extension Data {
    init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.count.isMultiple(of: 2), !hex.isEmpty else {
            if hex.isEmpty { self = Data(); return }
            return nil
        }
        var data = Data()
        data.reserveCapacity(hex.count / 2)
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2)
            guard let b = UInt8(hex[idx..<next], radix: 16) else { return nil }
            data.append(b)
            idx = next
        }
        self = data
    }
}
