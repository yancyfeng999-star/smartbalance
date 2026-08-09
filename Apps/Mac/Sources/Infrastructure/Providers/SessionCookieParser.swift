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
}
