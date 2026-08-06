import Foundation
import CryptoKit
import Domain

/// 火山引擎 OpenAPI 签名（HMAC-SHA256 / V4 风格）。
/// 参考官方 demo：https://github.com/volcengine/volc-openapi-demos
public enum VolcengineSigner {
    public struct SignedRequest: Sendable {
        public let url: URL
        public let method: String
        public let headers: [String: String]
        public let body: Data
    }

    /// - Parameters:
    ///   - method: GET / POST
    ///   - host: e.g. billing.volcengineapi.com
    ///   - path: usually "/"
    ///   - query: Action / Version 等（不含签名参数）
    ///   - body: POST 体；GET 用空 Data
    ///   - accessKeyId / secretAccessKey: 访问密钥
    ///   - service / region: 签名 scope
    ///   - contentType: 参与签名的 Content-Type
    ///   - now: 可注入便于单测
    public static func sign(
        method: String,
        host: String,
        path: String = "/",
        query: [String: String],
        body: Data = Data(),
        accessKeyId: String,
        secretAccessKey: String,
        service: String,
        region: String,
        contentType: String,
        now: Date = Date()
    ) throws -> SignedRequest {
        let methodU = method.uppercased()
        let xDate = iso8601Basic(now)
        let shortDate = String(xDate.prefix(8))
        let payloadHash = sha256Hex(body)

        let queryString = canonicalQuery(query)
        let signedHeaders = ["content-type", "host", "x-content-sha256", "x-date"]
        let canonicalHeaders = [
            "content-type:\(contentType)",
            "host:\(host)",
            "x-content-sha256:\(payloadHash)",
            "x-date:\(xDate)",
        ].joined(separator: "\n")

        let canonicalRequest = [
            methodU,
            path,
            queryString,
            canonicalHeaders,
            "",
            signedHeaders.joined(separator: ";"),
            payloadHash,
        ].joined(separator: "\n")

        let hashedCanonical = sha256Hex(Data(canonicalRequest.utf8))
        let credentialScope = "\(shortDate)/\(region)/\(service)/request"
        let stringToSign = [
            "HMAC-SHA256",
            xDate,
            credentialScope,
            hashedCanonical,
        ].joined(separator: "\n")

        let signingKey = derivedSigningKey(
            secret: secretAccessKey,
            shortDate: shortDate,
            region: region,
            service: service
        )
        let signature = hmacSHA256Hex(key: signingKey, message: stringToSign)

        let authorization =
            "HMAC-SHA256 Credential=\(accessKeyId)/\(credentialScope), " +
            "SignedHeaders=\(signedHeaders.joined(separator: ";")), " +
            "Signature=\(signature)"

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.percentEncodedQuery = queryString.isEmpty ? nil : queryString
        guard let url = components.url else {
            throw BalanceProviderError.invalidURL
        }

        let headers: [String: String] = [
            "Content-Type": contentType,
            "Host": host,
            "X-Date": xDate,
            "X-Content-Sha256": payloadHash,
            "Authorization": authorization,
        ]

        return SignedRequest(url: url, method: methodU, headers: headers, body: body)
    }

    // MARK: - Helpers

    public static func packCredentials(accessKeyId: String, secretAccessKey: String) -> String {
        let ak = accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines)
        let sk = secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(ak)\n\(sk)"
    }

    public static func unpackCredentials(_ packed: String) -> (accessKeyId: String, secretAccessKey: String)? {
        let trimmed = packed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 优先换行分隔（UI 保存格式）
        if let nl = trimmed.range(of: "\n") {
            let ak = String(trimmed[..<nl.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let sk = String(trimmed[nl.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !ak.isEmpty, !sk.isEmpty { return (ak, sk) }
        }
        // 兼容 AK|SK
        if let bar = trimmed.range(of: "|") {
            let ak = String(trimmed[..<bar.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let sk = String(trimmed[bar.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !ak.isEmpty, !sk.isEmpty { return (ak, sk) }
        }
        return nil
    }

    private static func canonicalQuery(_ query: [String: String]) -> String {
        let pairs = query.keys.sorted().compactMap { key -> String? in
            guard let value = query[key] else { return nil }
            return "\(uriEncode(key))=\(uriEncode(value))"
        }
        return pairs.joined(separator: "&")
    }

    /// RFC 3986 风格，空格 → %20
    private static func uriEncode(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    private static func iso8601Basic(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func hmacSHA256(key: Data, message: String) -> Data {
        let keySym = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: keySym)
        return Data(mac)
    }

    private static func hmacSHA256Hex(key: Data, message: String) -> String {
        hmacSHA256(key: key, message: message).map { String(format: "%02x", $0) }.joined()
    }

    private static func derivedSigningKey(secret: String, shortDate: String, region: String, service: String) -> Data {
        let kDate = hmacSHA256(key: Data(secret.utf8), message: shortDate)
        let kRegion = hmacSHA256(key: kDate, message: region)
        let kService = hmacSHA256(key: kRegion, message: service)
        return hmacSHA256(key: kService, message: "request")
    }
}
