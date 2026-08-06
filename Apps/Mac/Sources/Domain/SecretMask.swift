import Foundation

/// 密钥展示：两端可见、中间隐藏（如 `sk-••••xyz`），避免「空框像没填」。
public enum SecretMask: Sendable {
    public static func display(_ secret: String, head: Int = 4, tail: Int = 4) -> String {
        let s = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }
        if s.count <= head + tail {
            if s.count <= 2 { return String(repeating: "•", count: s.count) }
            return String(s.prefix(1)) + String(repeating: "•", count: max(2, s.count - 2)) + String(s.suffix(1))
        }
        return String(s.prefix(head)) + "••••" + String(s.suffix(tail))
    }
}
