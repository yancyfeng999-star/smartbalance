import Foundation
import Network
import Domain

/// 极简 IMAP 客户端：LOGIN → SELECT → 拉最近 N 封的头+正文。
/// 推荐 993 + 隐式 TLS。
public actor IMAPClient {
    public init() {}

    public func fetchRecent(
        host: String,
        port: Int,
        useTLS: Bool,
        username: String,
        password: String,
        folder: String,
        maxMessages: Int
    ) async throws -> [FetchedMailMessage] {
        let connection = IMAPConnection(
            host: host,
            port: UInt16(port),
            implicitTLS: useTLS || port == 993
        )
        try await connection.start()
        defer { connection.cancel() }

        _ = try await connection.readLine() // banner * OK

        try await connection.sendCommand("LOGIN \(quote(username)) \(quote(password))")
        let login = try await connection.readTagged()
        guard login.uppercased().contains("OK") else {
            throw IMAPError.authFailed(login)
        }

        try await connection.sendCommand("SELECT \(quote(folder))")
        let select = try await connection.readTagged()
        guard select.uppercased().contains("OK") else {
            throw IMAPError.commandFailed(select)
        }

        // 解析 EXISTS
        let exists = parseExists(from: select) ?? 0
        guard exists > 0 else { return [] }

        let count = min(max(1, maxMessages), exists)
        let start = max(1, exists - count + 1)
        let set = "\(start):\(exists)"

        try await connection.sendCommand(
            "FETCH \(set) (BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE MESSAGE-ID)] BODY.PEEK[TEXT])"
        )
        let fetchBlob = try await connection.readTagged()
        return parseFetch(fetchBlob)
    }

    private func quote(_ s: String) -> String {
        "\"\(s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private func parseExists(from text: String) -> Int? {
        // * 12 EXISTS
        let re = try? NSRegularExpression(pattern: #"\* (\d+) EXISTS"#, options: [])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = re?.firstMatch(in: text, range: range),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return Int(text[r])
    }

    private func parseFetch(_ blob: String) -> [FetchedMailMessage] {
        // 粗解析：按 "* N FETCH" 分块
        let parts = blob.components(separatedBy: "\r\n* ")
        var results: [FetchedMailMessage] = []

        for (idx, part) in parts.enumerated() {
            let block = idx == 0 ? part : "* " + part
            guard block.uppercased().contains("FETCH") || block.contains("BODY") else { continue }

            let from = headerField("From", in: block) ?? ""
            let subject = decodeMIME(headerField("Subject", in: block) ?? "")
            let messageId = headerField("Message-ID", in: block)
                ?? headerField("Message-Id", in: block)
                ?? "seq-\(idx)-\(from.hashValue)"
            let body = extractTextBody(from: block)
            if from.isEmpty && subject.isEmpty && body.isEmpty { continue }

            results.append(FetchedMailMessage(
                id: messageId.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")),
                from: from,
                subject: subject,
                body: body
            ))
        }
        return results
    }

    private func headerField(_ name: String, in block: String) -> String? {
        let pattern = #"^\#(name):\s*(.*)$"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]) else {
            return nil
        }
        let range = NSRange(block.startIndex..<block.endIndex, in: block)
        guard let m = re.firstMatch(in: block, range: range),
              let r = Range(m.range(at: 1), in: block) else { return nil }
        return String(block[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTextBody(from block: String) -> String {
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

    private func decodeMIME(_ raw: String) -> String {
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

public enum IMAPError: Error, LocalizedError, Sendable {
    case authFailed(String)
    case commandFailed(String)
    case connection(String)

    public var errorDescription: String? {
        switch self {
        case .authFailed(let s): "IMAP 登录失败: \(s.prefix(120))"
        case .commandFailed(let s): "IMAP 命令失败: \(s.prefix(120))"
        case .connection(let s): "IMAP 连接: \(s)"
        }
    }
}

// MARK: - Connection

private final class IMAPConnection: @unchecked Sendable {
    private let host: String
    private let port: UInt16
    private let implicitTLS: Bool
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.smartbalance.imap")
    private var buffer = Data()
    private var tagCounter = 0

    init(host: String, port: UInt16, implicitTLS: Bool) {
        self.host = host
        self.port = port
        self.implicitTLS = implicitTLS
    }

    func start() async throws {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        let params: NWParameters
        if implicitTLS {
            params = NWParameters(tls: NWProtocolTLS.Options(), tcp: NWProtocolTCP.Options())
        } else {
            params = .tcp
        }
        let conn = NWConnection(to: endpoint, using: params)
        self.connection = conn
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    conn.stateUpdateHandler = nil
                    cont.resume()
                case .failed(let err):
                    conn.stateUpdateHandler = nil
                    cont.resume(throwing: IMAPError.connection(err.localizedDescription))
                case .cancelled:
                    conn.stateUpdateHandler = nil
                    cont.resume(throwing: IMAPError.connection("cancelled"))
                default: break
                }
            }
            conn.start(queue: queue)
        }
    }

    func cancel() {
        connection?.cancel()
        connection = nil
    }

    func sendCommand(_ command: String) async throws {
        tagCounter += 1
        let tag = String(format: "A%03d", tagCounter)
        let line = "\(tag) \(command)\r\n"
        try await sendRaw(line)
    }

    func readLine() async throws -> String {
        while true {
            if let idx = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.subdata(in: 0..<idx)
                buffer.removeSubrange(0...idx)
                var s = String(data: lineData, encoding: .utf8) ?? ""
                if s.hasSuffix("\r") { s.removeLast() }
                return s
            }
            try await receiveMore()
        }
    }

    /// 读到对应 tag 的完成行（含中间 * 行）。
    func readTagged() async throws -> String {
        let tag = String(format: "A%03d", tagCounter)
        var collected = ""
        while true {
            let line = try await readLine()
            collected += line + "\n"
            if line.hasPrefix(tag + " ") {
                return collected
            }
            // 字面量 {size}
            if let re = try? NSRegularExpression(pattern: #"\{(\d+)\}$"#),
               let m = re.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)),
               let r = Range(m.range(at: 1), in: line),
               let size = Int(line[r]) {
                let literal = try await readExact(size)
                collected += literal
                // 字面量后通常还有一行
            }
        }
    }

    private func readExact(_ size: Int) async throws -> String {
        while buffer.count < size {
            try await receiveMore()
        }
        let data = buffer.prefix(size)
        buffer.removeFirst(size)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func sendRaw(_ text: String) async throws {
        guard let connection, let data = text.data(using: .utf8) else {
            throw IMAPError.connection("no connection")
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    cont.resume(throwing: IMAPError.connection(error.localizedDescription))
                } else {
                    cont.resume()
                }
            })
        }
    }

    private func receiveMore() async throws {
        let chunk: Data = try await withCheckedThrowingContinuation { cont in
            connection?.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { data, _, isComplete, error in
                if let error {
                    cont.resume(throwing: IMAPError.connection(error.localizedDescription))
                    return
                }
                if let data, !data.isEmpty {
                    cont.resume(returning: data)
                } else if isComplete {
                    cont.resume(throwing: IMAPError.connection("closed"))
                } else {
                    cont.resume(returning: Data())
                }
            }
        }
        buffer.append(chunk)
    }
}
