import Foundation
import Network
import Domain

/// 极简 IMAP 客户端：LOGIN → SELECT → 拉最近 N 封的头+正文。
/// 推荐 993 + 隐式 TLS。解析逻辑见 `IMAPFetchParser`。
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
            // SELECT 失败多数为文件夹不存在 / 无权限
            throw IMAPError.folderNotFound(folder)
        }

        // 解析 EXISTS
        let exists = IMAPFetchParser.parseExists(from: select) ?? 0
        guard exists > 0 else { return [] }

        let count = min(max(1, maxMessages), exists)
        let start = max(1, exists - count + 1)
        let set = "\(start):\(exists)"

        try await connection.sendCommand(
            "FETCH \(set) (BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE MESSAGE-ID)] BODY.PEEK[TEXT])"
        )
        let fetchBlob = try await connection.readTagged()
        return IMAPFetchParser.parseFetchResponse(fetchBlob)
    }

    private func quote(_ s: String) -> String {
        "\"\(s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}

public enum IMAPError: Error, LocalizedError, Sendable {
    case authFailed(String)
    case folderNotFound(String)
    case commandFailed(String)
    case timeout
    case connection(String)

    public var errorDescription: String? {
        switch self {
        case .authFailed:
            "IMAP 登录失败，请检查邮箱与授权码"
        case .folderNotFound(let folder):
            "文件夹不存在：\(folder)"
        case .timeout:
            "IMAP 连接超时"
        case .commandFailed(let s):
            "IMAP 命令失败: \(s.prefix(120))"
        case .connection(let s):
            if Self.looksLikeTimeout(s) {
                "IMAP 连接超时"
            } else {
                "IMAP 连接: \(s)"
            }
        }
    }

    private static func looksLikeTimeout(_ s: String) -> Bool {
        let lower = s.lowercased()
        return lower.contains("timeout")
            || lower.contains("timed out")
            || lower.contains("time out")
            || lower.contains("超时")
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
                    cont.resume(throwing: Self.mapConnectionError(err.localizedDescription))
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
                    cont.resume(throwing: Self.mapConnectionError(error.localizedDescription))
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
                    cont.resume(throwing: Self.mapConnectionError(error.localizedDescription))
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

    private static func mapConnectionError(_ message: String) -> IMAPError {
        let lower = message.lowercased()
        if lower.contains("timeout") || lower.contains("timed out") || lower.contains("time out") || message.contains("超时") {
            return .timeout
        }
        return .connection(message)
    }
}
