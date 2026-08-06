import Foundation
import Network
import Domain

/// SMTP 报文格式（可单测）：RFC 2047 主题编码与 DATA 终结符。
public enum SMTPProtocolFormatting: Sendable {
    /// RFC 2047 UTF-8 Base64 encoded-word。
    public static func encodeSubject(_ subject: String) -> String {
        let b64 = Data(subject.utf8).base64EncodedString()
        return "=?UTF-8?B?\(b64)?="
    }

    /// 构建 DATA 段载荷；必须以 `\r\n.\r\n` 终结。
    public static func buildDATAPayload(
        fromDisplay: String,
        fromAddress: String,
        toAddresses: [String],
        subject: String,
        body: String,
        date: Date = Date()
    ) -> String {
        let toHeader = toAddresses.joined(separator: ", ")
        let dateStr = RFC2822DateFormatter.string(from: date)
        // 显式 CRLF，避免多行字符串插值在不同平台上变成 LF-only
        var lines: [String] = [
            "From: \(fromDisplay) <\(fromAddress)>",
            "To: \(toHeader)",
            "Subject: \(encodeSubject(subject))",
            "Date: \(dateStr)",
            "MIME-Version: 1.0",
            "Content-Type: text/plain; charset=utf-8",
            "Content-Transfer-Encoding: 8bit",
            "",
        ]
        // 正文行：裸「.」行需 dot-stuffing；末尾追加终结符
        let bodyLines = body.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let s = String(line)
                return s.hasPrefix(".") ? "." + s : s
            }
        lines.append(contentsOf: bodyLines)
        lines.append(".")
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// 推荐路径：465 + 隐式 TLS。
    public static let recommendedPortHint = "推荐 465 + TLS（隐式 TLS）"

    /// 587 STARTTLS 暂不支持时的提示。
    public static let startTLSUnsupportedHint = "当前版本请改用 465 + TLS。587 STARTTLS 暂不支持。"
}

/// 极简 SMTP 客户端：推荐 465 隐式 TLS（NWProtocolTLS）。
/// 587 STARTTLS：Network.framework 无法原地升级，给出明确错误引导改用 465。
public actor SMTPClient {
    public init() {}

    public func send(
        settings: EmailAlertSettings,
        password: String,
        subject: String,
        body: String
    ) async throws {
        guard settings.isConfigured else {
            throw SMTPError.notConfigured
        }
        guard !password.isEmpty else {
            throw SMTPError.missingPassword
        }

        let host = settings.smtpHost
        let port = UInt16(settings.smtpPort)
        let from = settings.fromAddress
        let recipients = settings.toAddresses.filter { $0.contains("@") }
        guard !recipients.isEmpty else { throw SMTPError.notConfigured }

        // 推荐路径：465 + 隐式 TLS。587 STARTTLS 本版不支持。
        if port == 587 {
            throw SMTPError.connection(SMTPProtocolFormatting.startTLSUnsupportedHint)
        }

        let connection = makeConnection(host: host, port: port, useTLS: settings.useTLS)
        try await connection.start()

        defer { connection.cancel() }

        // Banner
        _ = try await connection.readReply()

        try await connection.sendLine("EHLO smartbalance.local")
        _ = try await connection.readReply()

        try await connection.sendLine("AUTH LOGIN")
        _ = try await connection.readReply()
        try await connection.sendLine(Data(settings.username.utf8).base64EncodedString())
        _ = try await connection.readReply()
        try await connection.sendLine(Data(password.utf8).base64EncodedString())
        let authReply = try await connection.readReply()
        if !authReply.hasPrefix("235") && !authReply.hasPrefix("2") {
            throw SMTPError.authFailed(authReply)
        }

        try await connection.sendLine("MAIL FROM:<\(from)>")
        _ = try await connection.readReply()
        for r in recipients {
            try await connection.sendLine("RCPT TO:<\(r)>")
            _ = try await connection.readReply()
        }
        try await connection.sendLine("DATA")
        _ = try await connection.readReply()

        let message = SMTPProtocolFormatting.buildDATAPayload(
            fromDisplay: Brand.nameCN,
            fromAddress: from,
            toAddresses: recipients,
            subject: subject,
            body: body
        )
        try await connection.sendRaw(message)
        let dataReply = try await connection.readReply()
        if !dataReply.hasPrefix("250") {
            throw SMTPError.sendFailed(dataReply)
        }
        try await connection.sendLine("QUIT")
        _ = try? await connection.readReply()
    }

    public func sendTest(settings: EmailAlertSettings, password: String) async throws {
        try await send(
            settings: settings,
            password: password,
            subject: "【\(Brand.nameCN)】邮件报警测试",
            body: """
            这是一封来自 \(Brand.nameCN)（\(Brand.nameEN)）的测试邮件。

            若你收到此信，说明 SMTP 配置可用。
            时间：\(ISO8601DateFormatter().string(from: Date()))
            """
        )
    }

    private func makeConnection(host: String, port: UInt16, useTLS: Bool) -> SMTPConnection {
        // 仅 465/443 + useTLS 走隐式 TLS；587 不支持
        SMTPConnection(host: host, port: port, implicitTLS: useTLS && (port == 465 || port == 443))
    }
}

public enum SMTPError: Error, LocalizedError, Sendable {
    case notConfigured
    case missingPassword
    case authFailed(String)
    case sendFailed(String)
    case connection(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured: "邮件未配置完整（主机/发件人/收件人）"
        case .missingPassword: "缺少 SMTP 密码"
        case .authFailed(let m): "SMTP 认证失败: \(m)"
        case .sendFailed(let m): "发送失败: \(m)"
        case .connection(let m): "连接失败: \(m)"
        }
    }
}

// MARK: - Connection

private final class SMTPConnection: @unchecked Sendable {
    private let host: String
    private let port: UInt16
    private let implicitTLS: Bool
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.smartbalance.smtp")
    private var buffer = Data()

    init(host: String, port: UInt16, implicitTLS: Bool) {
        self.host = host
        self.port = port
        self.implicitTLS = implicitTLS
    }

    func start() async throws {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        let params: NWParameters
        if implicitTLS {
            let tls = NWProtocolTLS.Options()
            params = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
        } else {
            params = NWParameters.tcp
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
                    cont.resume(throwing: SMTPError.connection(err.localizedDescription))
                case .cancelled:
                    conn.stateUpdateHandler = nil
                    cont.resume(throwing: SMTPError.connection("cancelled"))
                default:
                    break
                }
            }
            conn.start(queue: queue)
        }
    }

    func upgradeToTLS() async throws {
        // Network.framework 无法在已有 TCP 上升级；587 场景若需 STARTTLS，
        // 建议用户改用 465 隐式 TLS。此处给出明确错误。
        throw SMTPError.connection("请使用 465 端口 + 开启 TLS（隐式 TLS）。当前版本暂不支持 STARTTLS 升级。")
    }

    func cancel() {
        connection?.cancel()
        connection = nil
    }

    func sendLine(_ line: String) async throws {
        try await sendRaw(line + "\r\n")
    }

    func sendRaw(_ text: String) async throws {
        guard let connection, let data = text.data(using: .utf8) else {
            throw SMTPError.connection("no connection")
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    cont.resume(throwing: SMTPError.connection(error.localizedDescription))
                } else {
                    cont.resume()
                }
            })
        }
    }

    func readReply() async throws -> String {
        // SMTP 多行回复以「code 」开头的行结束（第三位为空格）。
        while true {
            if let reply = try extractCompleteReply() {
                return reply
            }
            let chunk: Data = try await withCheckedThrowingContinuation { cont in
                connection?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
                    if let error {
                        cont.resume(throwing: SMTPError.connection(error.localizedDescription))
                        return
                    }
                    if let data, !data.isEmpty {
                        cont.resume(returning: data)
                    } else if isComplete {
                        cont.resume(throwing: SMTPError.connection("connection closed"))
                    } else {
                        cont.resume(returning: Data())
                    }
                }
            }
            buffer.append(chunk)
        }
    }

    private func extractCompleteReply() throws -> String? {
        guard let text = String(data: buffer, encoding: .utf8) else { return nil }
        var lines: [String] = []
        var consumed = 0
        let all = text.split(separator: "\n", omittingEmptySubsequences: false)
        var offset = 0
        for (i, raw) in all.enumerated() {
            let line = raw.hasSuffix("\r") ? String(raw.dropLast()) : String(raw)
            offset += raw.count + 1
            if line.count < 3 { continue }
            lines.append(line)
            let codePart = line.prefix(3)
            let sep = line.count > 3 ? line[line.index(line.startIndex, offsetBy: 3)] : " "
            if codePart.allSatisfy(\.isNumber) && sep == " " {
                consumed = offset
                let reply = lines.joined(separator: "\n")
                if consumed <= buffer.count {
                    buffer.removeSubrange(0..<consumed)
                } else {
                    buffer.removeAll()
                }
                return reply
            }
            // 多行：code-
            _ = i
        }
        return nil
    }
}

private enum RFC2822DateFormatter {
    static func string(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss '+0000'"
        return f.string(from: date)
    }
}
