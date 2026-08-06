import Foundation

/// 从平台邮件正文/主题中提取余额。
public enum BalanceMailParser: Sendable {
    /// 内置模式：捕获金额数字。
    public static let builtInPatterns: [String] = [
        #"余额[为是:：\s]*[¥￥$]?\s*([0-9]+(?:\.[0-9]+)?)"#,
        #"剩余[额度金额余额]*[为是:：\s]*[¥￥$]?\s*([0-9]+(?:\.[0-9]+)?)"#,
        #"balance[:\s]*[¥￥$]?\s*([0-9]+(?:\.[0-9]+)?)"#,
        #"remaining[:\s]*[¥￥$]?\s*([0-9]+(?:\.[0-9]+)?)"#,
        #"[¥￥]\s*([0-9]+(?:\.[0-9]+)?)"#,
        #"\$\s*([0-9]+(?:\.[0-9]+)?)"#,
        #"credits?[:\s]*([0-9]+(?:\.[0-9]+)?)"#,
        #"额度[为是:：\s]*([0-9]+(?:\.[0-9]+)?)"#,
    ]

    public static func extractAmount(from text: String, customRegex: String?) -> Double? {
        let candidates: [String]
        if let custom = customRegex?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            candidates = [custom] + builtInPatterns
        } else {
            candidates = builtInPatterns
        }

        let haystack = text
        for pattern in candidates {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
            if let match = regex.firstMatch(in: haystack, options: [], range: range),
               match.numberOfRanges >= 2,
               let r = Range(match.range(at: 1), in: haystack) {
                let raw = String(haystack[r]).replacingOccurrences(of: ",", with: "")
                if let v = Double(raw) { return v }
            }
        }
        return nil
    }

    /// 主题/正文是否像「平台报警」信（即使金额解析失败也要推送）。
    public static func looksLikeAlert(subject: String, body: String) -> Bool {
        let s = (subject + "\n" + body).lowercased()
        let keys = ["不足", "欠费", "耗尽", "告警", "报警", "预警", "low balance", "insufficient", "depleted", "overdue", "余额提醒", "用量告警"]
        return keys.contains { s.contains($0.lowercased()) }
    }

    public static func matches(message: FetchedMailMessage, source: PlatformMailSource) -> Bool {
        let fromOK = source.fromContains.isEmpty
            || message.from.localizedCaseInsensitiveContains(source.fromContains)
        let subjectOK = source.subjectContains.isEmpty
            || message.subject.localizedCaseInsensitiveContains(source.subjectContains)
        return fromOK && subjectOK
    }
}
