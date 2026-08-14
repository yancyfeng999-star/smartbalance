import Foundation

/// 导出/诊断脱敏基础。Task 4 会扩展规则；此处只拦设置迁移包禁止字段。
public enum PrivacyRedactor: Sendable {
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
}
