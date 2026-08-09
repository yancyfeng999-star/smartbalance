import Foundation
import Domain
import CommonCrypto
import Security

/// 从本机 Chrome / Edge 读取已登录控制台的 Cookie，供 MiMo / MiniMax 新用户一键导入。
public enum BrowserSessionImporter: Sendable {
    public struct Credential: Sendable, Equatable {
        public var secret: String
        public var userId: String?
        public var source: String
    }

    public enum ImportError: Error, LocalizedError, Sendable {
        case unsupportedKind
        case browserNotFound
        case keychainDenied(String)
        case cookieNotFound(String)
        case decryptFailed

        public var errorDescription: String? {
            switch self {
            case .unsupportedKind:
                return "当前平台不支持浏览器导入"
            case .browserNotFound:
                return "未找到 Chrome / Edge Cookie。请先安装并登录后重试"
            case .keychainDenied(let s):
                return "无法读取浏览器密钥链：\(s)。若弹出钥匙串权限请点「允许」"
            case .cookieNotFound(let s):
                return s
            case .decryptFailed:
                return "Cookie 解密失败。请完全退出浏览器后再试，或手动粘贴 Cookie"
            }
        }
    }

    /// 按平台从本机浏览器取会话。
    public static func importSession(for kind: ProviderKind) throws -> Credential {
        switch kind {
        case .mimo:
            return try importMiMo()
        case .minimax:
            return try importMiniMax()
        default:
            throw ImportError.unsupportedKind
        }
    }

    // MARK: - Platforms

    private static func importMiMo() throws -> Credential {
        let cookies = try loadCookies(hostContains: ["xiaomimimo.com", "platform.xiaomimimo.com"])
        let token = cookies.first(where: { $0.name == "api-platform_serviceToken" })?.value
        let userId = cookies.first(where: { $0.name == "userId" })?.value
        guard let token, !token.isEmpty else {
            throw ImportError.cookieNotFound(
                "未找到 MiMo 登录 Cookie。请先在 Chrome 打开并登录 https://platform.xiaomimimo.com/console/balance 后再点导入"
            )
        }
        guard let userId, !userId.isEmpty else {
            throw ImportError.cookieNotFound(
                "找到 serviceToken，但缺少 userId。请确认已登录控制台后重试"
            )
        }
        let source = cookies.first?.browserName ?? "Chrome"
        return Credential(secret: token, userId: userId, source: source)
    }

    private static func importMiniMax() throws -> Credential {
        let cookies = try loadCookies(hostContains: ["minimaxi.com", "minimax.io"])
        // 优先 www 的 _token
        let wwwToken = cookies.first(where: { $0.name == "_token" && $0.host.contains("www.minimaxi") })?.value
        let anyToken = cookies.first(where: { $0.name == "_token" })?.value
        let token = wwwToken ?? anyToken
        let groupId = cookies.first(where: { $0.name == "minimax_group_id_v2" })?.value
        guard let token, !token.isEmpty else {
            throw ImportError.cookieNotFound(
                "未找到 MiniMax 登录 Cookie。请先在 Chrome 打开并登录 https://platform.minimaxi.com/console/recharge-records 后再点导入"
            )
        }
        guard let groupId, !groupId.isEmpty else {
            throw ImportError.cookieNotFound(
                "找到 _token，但缺少 minimax_group_id_v2。请在控制台登录后刷新页面再试"
            )
        }
        let source = cookies.first?.browserName ?? "Chrome"
        // 拼成可被 SessionCookieParser 识别的串，便于后续解析
        let secret = "_token=\(token); minimax_group_id_v2=\(groupId)"
        return Credential(secret: secret, userId: groupId, source: source)
    }

    // MARK: - Cookie DB

    private struct CookieRow: Sendable {
        var host: String
        var name: String
        var value: String
        var browserName: String
    }

    private static func loadCookies(hostContains: [String]) throws -> [CookieRow] {
        let browsers: [(name: String, cookiesPath: String, keychainService: String, keychainAccount: String)] = [
            (
                "Chrome",
                NSHomeDirectory() + "/Library/Application Support/Google/Chrome/Default/Cookies",
                "Chrome Safe Storage",
                "Chrome"
            ),
            (
                "Chrome",
                NSHomeDirectory() + "/Library/Application Support/Google/Chrome/Profile 1/Cookies",
                "Chrome Safe Storage",
                "Chrome"
            ),
            (
                "Edge",
                NSHomeDirectory() + "/Library/Application Support/Microsoft Edge/Default/Cookies",
                "Microsoft Edge Safe Storage",
                "Microsoft Edge"
            ),
        ]

        var all: [CookieRow] = []
        var sawDB = false
        var lastKeychainError: String?

        for browser in browsers {
            guard FileManager.default.fileExists(atPath: browser.cookiesPath) else { continue }
            sawDB = true
            let key: Data
            do {
                key = try chromeEncryptionKey(
                    service: browser.keychainService,
                    account: browser.keychainAccount
                )
            } catch {
                lastKeychainError = error.localizedDescription
                continue
            }
            do {
                let rows = try readCookieDB(
                    path: browser.cookiesPath,
                    key: key,
                    hostContains: hostContains,
                    browserName: browser.name
                )
                all.append(contentsOf: rows)
            } catch {
                AppLog.error("Cookie DB read failed \(browser.cookiesPath): \(error.localizedDescription)")
            }
        }

        if !sawDB {
            throw ImportError.browserNotFound
        }
        if all.isEmpty, let lastKeychainError {
            throw ImportError.keychainDenied(lastKeychainError)
        }
        return all
    }

    private static func readCookieDB(
        path: String,
        key: Data,
        hostContains: [String],
        browserName: String
    ) throws -> [CookieRow] {
        // Chrome 可能锁库，复制到临时文件再读
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("smartbalance-cookies-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try FileManager.default.copyItem(atPath: path, toPath: tmp.path)

        // 用 sqlite3 命令行，避免引入 SQLite.swift 依赖
        let query = """
        SELECT host_key, name, CAST(encrypted_value AS BLOB), value
        FROM cookies;
        """
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        // hex output for blob: use custom - not easy. Use Python-free: open with SQLite C via...
        // Fall back to FileHandle + sqlite3 with quote mode is messy for binary.
        // Use NSData from running a small inline approach via `sqlite3` and base64:
        proc.arguments = [
            tmp.path,
            """
            SELECT host_key || char(1) || name || char(1) ||
                   hex(encrypted_value) || char(1) || IFNULL(value,'')
            FROM cookies;
            """,
        ]
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        try proc.run()
        proc.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        if proc.terminationStatus != 0 {
            let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw ImportError.cookieNotFound("读取 Cookie 数据库失败：\(e)")
        }

        var rows: [CookieRow] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: "\u{0001}", omittingEmptySubsequences: false)
            guard parts.count >= 4 else { continue }
            let host = String(parts[0])
            let name = String(parts[1])
            let hex = String(parts[2])
            let plainCol = String(parts[3])
            let hostOK = hostContains.contains { host.localizedCaseInsensitiveContains($0) }
            guard hostOK else { continue }

            let value: String
            if !plainCol.isEmpty {
                value = plainCol
            } else {
                guard let enc = Data(hexString: hex), let dec = decryptChromeV10(enc, key: key) else {
                    continue
                }
                value = dec
            }
            guard !value.isEmpty else { continue }
            rows.append(CookieRow(host: host, name: name, value: value, browserName: browserName))
        }
        return rows
    }

    // MARK: - Crypto

    private static func chromeEncryptionKey(service: String, account: String) throws -> Data {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        proc.arguments = ["find-generic-password", "-w", "-s", service, "-a", account]
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            throw ImportError.keychainDenied(error.localizedDescription)
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let password = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if proc.terminationStatus != 0 || password.isEmpty {
            let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "denied"
            throw ImportError.keychainDenied(e)
        }
        // PBKDF2-SHA1, salt "saltysalt", 1003 iters, 16 bytes
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

    /// Chrome macOS v10 cookie: AES-128-CBC, IV = 16 spaces, then strip 32-byte prefix if payload looks printable.
    private static func decryptChromeV10(_ encrypted: Data, key: Data) -> String? {
        guard encrypted.count > 3 else { return nil }
        let prefix = encrypted.prefix(3)
        guard prefix == Data("v10".utf8) || prefix == Data("v11".utf8) else {
            // maybe already plain
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
        // strip optional 32-byte chrome prefix when remainder is printable
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

private extension Data {
    init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.count.isMultiple(of: 2) else { return nil }
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
