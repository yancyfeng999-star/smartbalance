import Foundation

/// 从浏览器 Cookie 串或单独 Token 中解析控制台会话凭据。
public enum SessionCookieParser: Sendable {
    /// 在 `a=b; c=d` / `Cookie: a=b` 中取指定名；找不到返回 nil。
    public static func value(named name: String, in raw: String) -> String? {
        let text = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^Cookie:\s*"#, with: "", options: .regularExpression)
        guard !text.isEmpty else { return nil }

        for part in text.split(separator: ";") {
            let piece = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let eq = piece.firstIndex(of: "=") else { continue }
            let key = piece[..<eq].trimmingCharacters(in: .whitespacesAndNewlines)
            guard key == name else { continue }
            var value = String(piece[piece.index(after: eq)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if value.count >= 2, value.first == "\"", value.last == "\"" {
                value = String(value.dropFirst().dropLast())
            }
            return value.isEmpty ? nil : value
        }
        return nil
    }

    /// MiMo：密钥可为 serviceToken 本体，或含 `api-platform_serviceToken` / `userId` 的 Cookie。
    public static func resolveMiMo(secret: String, userId: String?) -> (token: String, userId: String?) {
        let raw = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        let token =
            value(named: "api-platform_serviceToken", in: raw)
            ?? (raw.contains("=") ? nil : raw)
            ?? raw
        let fromCookie = value(named: "userId", in: raw)
        let uid = (userId?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? fromCookie
        return (token.trimmingCharacters(in: .whitespacesAndNewlines), uid)
    }

    /// MiniMax：密钥可为 JWT `_token` 本体，或含 `_token=` 的 Cookie。
    public static func resolveMiniMaxToken(secret: String) -> String {
        let raw = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        if let t = value(named: "_token", in: raw) { return t }
        return raw
    }

    /// apinebula / New-API：从 session Cookie 解出用户 ID（gob 会话，无需手填）。
    public static func resolveApinebula(secret: String, userId: String?) -> (session: String, userId: String?) {
        let raw = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        let session =
            value(named: "session", in: raw)
            ?? (raw.lowercased().hasPrefix("cookie:")
                ? value(named: "session", in: String(raw.dropFirst(7)))
                : nil)
            ?? (raw.contains("=") && value(named: "session", in: raw) == nil ? nil : raw)
            ?? raw
        let sess = session.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicit = userId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let uid = (explicit?.isEmpty == false ? explicit : nil) ?? extractNewAPIUserId(fromSession: sess)
        return (sess, uid)
    }

    /// 从 New-API gorilla session 值解析用户 id（gob 编码：id 存为 id<<1 的 uint）。
    ///
    /// Cookie 形态：`base64url( timestamp | base64url(gob) | mac )`
    public static func extractNewAPIUserId(fromSession session: String) -> String? {
        let s = session.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        var blobs: [Data] = []
        if let outer = base64URLDecode(s) {
            blobs.append(outer)
            // timestamp | innerB64 | mac
            let parts = splitASCII(outer, separator: UInt8(ascii: "|"))
            if parts.count >= 2, let innerStr = String(data: parts[1], encoding: .utf8),
               let gob = base64URLDecode(innerStr)
            {
                blobs.insert(gob, at: 0) // gob 优先
            }
            // 兼容：内层直接是 gob 二进制
            if parts.count >= 2 {
                blobs.append(parts[1])
            }
        }
        // 兼容已是解码形态 / 裸 gob
        if let data = s.data(using: .utf8) { blobs.append(data) }

        var nearId: [Int] = []
        var others: [Int] = []

        for blob in blobs {
            if let idRange = blob.range(of: Data("id".utf8)) {
                let from = idRange.lowerBound
                let to = blob.index(from, offsetBy: min(48, blob.distance(from: from, to: blob.endIndex)))
                nearId.append(contentsOf: gobIntCandidates(in: [UInt8](blob[from..<to])))
            }
            others.append(contentsOf: gobIntCandidates(in: [UInt8](blob)))
        }

        let pick = (nearId + others).first { $0 >= 1 && $0 <= 50_000_000 }
        return pick.map(String.init)
    }

    private static func gobIntCandidates(in bytes: [UInt8]) -> [Int] {
        var multi: [Int] = []
        var single: [Int] = []
        guard !bytes.isEmpty else { return [] }
        for i in 0..<bytes.count {
            // gob multi-byte uint：0xFE + 2 字节大端（正 id 编码为 id<<1）
            if i + 2 < bytes.count, bytes[i] == 0xFE {
                let u = (Int(bytes[i + 1]) << 8) | Int(bytes[i + 2])
                if u > 0, u % 2 == 0 {
                    let id = u >> 1
                    // 过滤噪声：真实 UID 通常 ≥ 1，且双字节范围有意义
                    if id >= 1, id <= 50_000_000 { multi.append(id) }
                }
            }
        }
        // 仅当没有双字节候选时，才考虑极小 UID（id < 64）
        if multi.isEmpty {
            for b in bytes where b > 0 && b < 0x80 && b % 2 == 0 {
                let id = Int(b) >> 1
                if id >= 1, id < 64 { single.append(id) }
            }
        }
        return multi + single
    }

    private static func splitASCII(_ data: Data, separator: UInt8) -> [Data] {
        var parts: [Data] = []
        var start = data.startIndex
        var i = data.startIndex
        while i < data.endIndex {
            if data[i] == separator {
                parts.append(data[start..<i])
                start = data.index(after: i)
            }
            i = data.index(after: i)
        }
        if start < data.endIndex {
            parts.append(data[start..<data.endIndex])
        }
        return parts
    }

    private static func base64URLDecode(_ s: String) -> Data? {
        var str = s
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - str.count % 4) % 4
        if pad > 0 { str += String(repeating: "=", count: pad) }
        return Data(base64Encoded: str)
    }
}
