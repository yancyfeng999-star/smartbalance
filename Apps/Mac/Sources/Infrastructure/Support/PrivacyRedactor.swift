import Foundation

/// 导出/诊断脱敏。JSON 键名门闩供 portable 编码；值脱敏供日志与诊断包。
public enum PrivacyRedactor: Sendable {
    public static let redactedPlaceholder = "[REDACTED]"

    private static let forbiddenJSONKeys = [
        "secretref",
        "passwordref",
        "secrets",
        "apikey",
        "api_key",
        "authorization",
        "cookie",
        "accesstoken",
    ]

    public static func forbiddenExportFieldNames(inJSON data: Data) -> [String] {
        guard let text = String(data: data, encoding: .utf8)?.lowercased() else { return [] }
        var hits: [String] = []
        if text.contains("\"secretref\"") { hits.append("secretRef") }
        if text.contains("\"passwordref\"") { hits.append("passwordRef") }
        if text.contains("\"secrets\"") { hits.append("secrets") }
        for key in forbiddenJSONKeys where key != "secretref" && key != "passwordref" && key != "secrets" {
            if text.contains("\"\(key)\"") {
                hits.append(key)
            }
        }
        return hits
    }

    public static func containsForbiddenExportFields(_ data: Data) -> Bool {
        !forbiddenExportFieldNames(inJSON: data).isEmpty
    }

    public static func redact(_ data: Data) -> Data {
        guard let text = String(data: data, encoding: .utf8) else { return data }
        return Data(redact(text).utf8)
    }

    public static func redact(_ text: String) -> String {
        var output = text
        output = replace(
            output,
            pattern: #"(?i)"(api[_-]?key|password|secret|token|authorization|cookie|access[_-]?token|smtp[_-]?password|session)"\s*:\s*"(?:\\.|[^"\\])*""#,
            template: "\"$1\":\"\(redactedPlaceholder)\""
        )
        output = replace(
            output,
            pattern: #"(?i)\bauthorization:\s*[^\r\n]+"#,
            template: "Authorization: \(redactedPlaceholder)"
        )
        output = replace(
            output,
            pattern: #"(?i)\bbearer\s+[A-Za-z0-9._\-+=/]+"#,
            template: "Bearer \(redactedPlaceholder)"
        )
        output = replace(
            output,
            pattern: #"(?i)\b(?:set-)?cookie:\s*[^\r\n]+"#,
            template: "Cookie: \(redactedPlaceholder)"
        )
        output = replace(
            output,
            pattern: #"(?i)([?&])(token|key|api[_-]?key|session|access[_-]?token|auth|password|secret)=([^&#\s]+)"#,
            template: "$1$2=\(redactedPlaceholder)"
        )
        output = replace(
            output,
            pattern: #"(?i)(smtp[_-]?pass(?:word)?|password|api[_-]?key|x-api-key|access[_-]?token)\s*[:=]\s*\S+"#,
            template: "$1=\(redactedPlaceholder)"
        )
        output = replace(
            output,
            pattern: #"(?i)\bsk-[A-Za-z0-9_\-]{8,}"#,
            template: redactedPlaceholder
        )
        output = replace(
            output,
            pattern: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#,
            template: redactedPlaceholder
        )
        return output
    }

    private static func replace(_ input: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: template)
    }
}
