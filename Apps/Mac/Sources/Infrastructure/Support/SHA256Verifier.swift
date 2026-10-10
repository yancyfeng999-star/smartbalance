import Foundation
import CryptoKit

public enum SHA256Verifier: Sendable {
    public static func hexDigest(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func hexDigest(ofFile url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func parseManifest(_ text: String) -> [String: String] {
        var map: [String: String] = [:]
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 2 else { continue }
            let digest = parts[0].lowercased()
            guard digest.count == 64, digest.allSatisfy(\.isHexDigit) else { continue }
            var name = parts[1]
            if name.hasPrefix("*") {
                name.removeFirst()
            }
            map[name] = digest
        }
        return map
    }

    public static func expectedDigest(fileName: String, manifest: String) -> String? {
        let parsed = parseManifest(manifest)
        if let exact = parsed[fileName] { return exact }
        let base = URL(fileURLWithPath: fileName).lastPathComponent
        if let exact = parsed[base] { return exact }
        return parsed.first { $0.key.lowercased() == base.lowercased() }?.value
    }

    public static func matches(fileName: String, digest: String, manifest: String) -> Bool {
        guard let expected = expectedDigest(fileName: fileName, manifest: manifest) else { return false }
        return expected == digest.lowercased()
    }
}
