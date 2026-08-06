import Foundation
import CryptoKit
import Domain

/// 纯函数 IMAP FETCH / SELECT 文本解析（无网络依赖，便于单测）。
public enum IMAPFetchParser {
    /// 从 FETCH 响应 blob 解析邮件列表（含 HEADER + BODY[TEXT] 字面量）。
    public static func parseFetchResponse(_ blob: String) -> [FetchedMailMessage] {
        // 粗解析：按 "* N FETCH" 分块
        let parts = blob.components(separatedBy: "\r\n* ")
        var results: [FetchedMailMessage] = []

        for (idx, part) in parts.enumerated() {
            let block = idx == 0 ? part : "* " + part
            guard block.uppercased().contains("FETCH") || block.contains("BODY") else { continue }

            let from = headerField("From", in: block) ?? ""
            let subject = decodeMIME(headerField("Subject", in: block) ?? "")
            let dateRaw = headerField("Date", in: block)
            let date = dateRaw.flatMap { parseRFC2822Date($0) }
            let body = extractTextBody(from: block)
            let messageId = headerField("Message-ID", in: block)
                ?? headerField("Message-Id", in: block)
                ?? stableFallbackMessageId(from: from, subject: subject, dateHeader: dateRaw, body: body, index: idx)
            if from.isEmpty && subject.isEmpty && body.isEmpty { continue }

            results.append(FetchedMailMessage(
                id: messageId.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")),
                from: from,
                subject: subject,
                date: date,
                body: body
            ))
        }
        return results
    }

    /// 从 SELECT 或 untagged 行解析 EXISTS 数量。`* 12 EXISTS`
    public static func parseExists(from selectOrUntagged: String) -> Int? {
        let re = try? NSRegularExpression(pattern: #"\* (\d+) EXISTS"#, options: [])
        let range = NSRange(selectOrUntagged.startIndex..<selectOrUntagged.endIndex, in: selectOrUntagged)
        guard let m = re?.firstMatch(in: selectOrUntagged, range: range),
              let r = Range(m.range(at: 1), in: selectOrUntagged) else { return nil }
        return Int(selectOrUntagged[r])
    }

    // MARK: - Internals

    /// 稳定 Message-ID 回退：SHA256(from|subject|date|body.prefix) 十六进制前缀，跨进程稳定。
    public static func stableFallbackMessageId(
        from: String,
        subject: String,
        dateHeader: String?,
        body: String,
        index: Int
    ) -> String {
        let bodyPrefix = String(body.prefix(200))
        let material = "\(from)|\(subject)|\(dateHeader ?? "")|\(bodyPrefix)"
        let digest = SHA256.hash(data: Data(material.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "stable-\(String(hex.prefix(16)))-\(index)"
    }

    /// 简化 RFC 2822 Date 解析（常见 IMAP Date 头）。
    public static func parseRFC2822Date(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 去掉可选的尾部注释 (UTC) 等
        let cleaned: String = {
            if let open = trimmed.firstIndex(of: "(") {
                return String(trimmed[..<open]).trimmingCharacters(in: .whitespaces)
            }
            return trimmed
        }()

        let formats = [
            "EEE, d MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "d MMM yyyy HH:mm:ss Z",
            "dd MMM yyyy HH:mm:ss Z",
            "EEE, d MMM yyyy HH:mm:ss zzz",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: cleaned) {
                return date
            }
        }
        return nil
    }

    private static func headerField(_ name: String, in block: String) -> String? {
        let pattern = #"^\#(name):\s*(.*)$"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]) else {
            return nil
        }
        let range = NSRange(block.startIndex..<block.endIndex, in: block)
        guard let m = re.firstMatch(in: block, range: range),
              let r = Range(m.range(at: 1), in: block) else { return nil }
        return String(block[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractTextBody(from block: String) -> String {
        // BODY[TEXT] {size}\r\n<body>
        if let re = try? NSRegularExpression(pattern: #"BODY\[TEXT\]\s*\{(\d+)\}\r?\n"#, options: [.caseInsensitive]),
           let m = re.firstMatch(in: block, range: NSRange(block.startIndex..<block.endIndex, in: block)),
           let sizeR = Range(m.range(at: 1), in: block),
           let fullR = Range(m.range, in: block),
           let size = Int(block[sizeR]) {
            let start = fullR.upperBound
            if let end = block.index(start, offsetBy: size, limitedBy: block.endIndex) {
                return String(block[start..<end])
            }
            return String(block[start...])
        }
        // 退化：去掉头，返回剩余
        if let range = block.range(of: "\r\n\r\n") {
            return String(block[range.upperBound...]).prefix(8000).description
        }
        return String(block.suffix(4000))
    }

    private static func decodeMIME(_ raw: String) -> String {
        // 简化：=?UTF-8?B?...?=
        guard raw.contains("=?") else { return raw }
        var result = raw
        if let re = try? NSRegularExpression(pattern: #"=\?([^?]+)\?([BbQq])\?([^?]+)\?="#, options: []) {
            let ns = result as NSString
            let matches = re.matches(in: result, range: NSRange(location: 0, length: ns.length))
            for m in matches.reversed() {
                guard m.numberOfRanges >= 4 else { continue }
                let charset = ns.substring(with: m.range(at: 1))
                let enc = ns.substring(with: m.range(at: 2)).uppercased()
                let payload = ns.substring(with: m.range(at: 3))
                var decoded: String?
                if enc == "B", let data = Data(base64Encoded: payload) {
                    decoded = String(data: data, encoding: charset.uppercased().contains("UTF-8") ? .utf8 : .isoLatin1)
                        ?? String(data: data, encoding: .utf8)
                }
                if let decoded {
                    result = (result as NSString).replacingCharacters(in: m.range, with: decoded)
                }
            }
        }
        return result
    }
}
