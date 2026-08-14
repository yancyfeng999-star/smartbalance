import Foundation

public enum UpdateAssetKind: String, Sendable, Equatable, Codable {
    case pkg
    case dmg
}

public enum UpdateChecksumStatus: String, Sendable, Equatable, Codable {
    case verified
    case unverifiable
    case mismatch
    case notChecked
}

public enum UpdateChecksumDisplay: String, Sendable, Equatable {
    case verified
    case unverifiable
    case failed
    case pending

    public var localizationKey: String {
        switch self {
        case .verified: return "update.checksum.verified"
        case .unverifiable: return "update.checksum.unverifiable"
        case .failed: return "update.checksum.failed"
        case .pending: return "update.checksum.pending"
        }
    }
}

public enum UpdatePhase: String, Sendable, Equatable {
    case idle
    case checking
    case available
    case upToDate
    case failed
    case downloading
    case validating
    case awaitingInstallConfirm
    case installing
}

public enum UpdateSafetyLimits {
    public static let maxAssetBytes: Int64 = 400 * 1024 * 1024
    public static let diskReserveBytes: Int64 = 8 * 1024 * 1024
    public static let defaultMinimumMacOS = "15.0"
    public static let allowedExtensions: Set<String> = ["pkg", "dmg"]
}

public struct UpdateAsset: Sendable, Equatable {
    public var fileName: String
    public var downloadURL: URL
    public var byteSize: Int64
    public var kind: UpdateAssetKind

    public init(fileName: String, downloadURL: URL, byteSize: Int64, kind: UpdateAssetKind) {
        self.fileName = fileName
        self.downloadURL = downloadURL
        self.byteSize = byteSize
        self.kind = kind
    }
}

public struct UpdateReleaseDetails: Sendable, Equatable {
    public var currentVersion: String
    public var targetVersion: String
    public var publishedAt: Date?
    public var releaseNotesPlainText: String
    public var asset: UpdateAsset?
    public var minimumMacOS: String
    public var releasePageURL: URL?
    public var checksumManifestURL: URL?
    public var checksumManifestText: String?

    public init(
        currentVersion: String,
        targetVersion: String,
        publishedAt: Date? = nil,
        releaseNotesPlainText: String,
        asset: UpdateAsset? = nil,
        minimumMacOS: String = UpdateSafetyLimits.defaultMinimumMacOS,
        releasePageURL: URL? = nil,
        checksumManifestURL: URL? = nil,
        checksumManifestText: String? = nil
    ) {
        self.currentVersion = currentVersion
        self.targetVersion = targetVersion
        self.publishedAt = publishedAt
        self.releaseNotesPlainText = releaseNotesPlainText
        self.asset = asset
        self.minimumMacOS = minimumMacOS
        self.releasePageURL = releasePageURL
        self.checksumManifestURL = checksumManifestURL
        self.checksumManifestText = checksumManifestText
    }
}

public struct UpdateCandidate: Sendable, Equatable {
    public var currentVersion: String
    public var targetVersion: String
    public var minimumMacOS: String
    public var currentMacOS: String
    public var assetURL: URL
    public var assetFileName: String
    public var assetByteSize: Int64
    public var maxByteSize: Int64
    public var checksumManifestText: String?
    public var downloadedFileSHA256: String?
    public var downloadedFileURL: URL?

    public init(
        currentVersion: String,
        targetVersion: String,
        minimumMacOS: String,
        currentMacOS: String,
        assetURL: URL,
        assetFileName: String,
        assetByteSize: Int64,
        maxByteSize: Int64 = UpdateSafetyLimits.maxAssetBytes,
        checksumManifestText: String? = nil,
        downloadedFileSHA256: String? = nil,
        downloadedFileURL: URL? = nil
    ) {
        self.currentVersion = currentVersion
        self.targetVersion = targetVersion
        self.minimumMacOS = minimumMacOS
        self.currentMacOS = currentMacOS
        self.assetURL = assetURL
        self.assetFileName = assetFileName
        self.assetByteSize = assetByteSize
        self.maxByteSize = maxByteSize
        self.checksumManifestText = checksumManifestText
        self.downloadedFileSHA256 = downloadedFileSHA256
        self.downloadedFileURL = downloadedFileURL
    }

    public static func make(
        details: UpdateReleaseDetails,
        currentMacOS: String,
        downloadedSHA256: String? = nil,
        downloadedFileURL: URL? = nil
    ) -> UpdateCandidate? {
        guard let asset = details.asset else { return nil }
        return UpdateCandidate(
            currentVersion: details.currentVersion,
            targetVersion: details.targetVersion,
            minimumMacOS: details.minimumMacOS,
            currentMacOS: currentMacOS,
            assetURL: asset.downloadURL,
            assetFileName: asset.fileName,
            assetByteSize: asset.byteSize,
            checksumManifestText: details.checksumManifestText,
            downloadedFileSHA256: downloadedSHA256,
            downloadedFileURL: downloadedFileURL
        )
    }
}

public enum UpdateAssetName {
    public static func isAllowed(_ fileName: String) -> Bool {
        guard !fileName.contains(".."), !fileName.contains("/") else { return false }
        let base = URL(fileURLWithPath: fileName).lastPathComponent
        guard !base.isEmpty, !base.hasPrefix(".") else { return false }
        let ext = URL(fileURLWithPath: base).pathExtension.lowercased()
        guard UpdateSafetyLimits.allowedExtensions.contains(ext) else { return false }
        let stem = URL(fileURLWithPath: base).deletingPathExtension().lastPathComponent
        let lower = stem.lowercased()
        guard lower.hasPrefix("smartbalance") || stem.hasPrefix("智余") else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-智余"))
        return base.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

public enum UpdateVersion {
    public static func parse(_ raw: String) -> [Int]? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }
        var nums: [Int] = []
        nums.reserveCapacity(parts.count)
        for part in parts {
            guard let value = Int(part), value >= 0, String(value) == part else { return nil }
            nums.append(value)
        }
        return nums
    }

    /// `a > b` → 1; equal → 0; `a < b` → -1; malformed → nil.
    public static func compare(_ a: String, _ b: String) -> Int? {
        guard let lhs = parse(a), let rhs = parse(b) else { return nil }
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let x = index < lhs.count ? lhs[index] : 0
            let y = index < rhs.count ? rhs[index] : 0
            if x != y { return x > y ? 1 : -1 }
        }
        return 0
    }
}

public enum UpdateReleaseNotes {
    public static func plainTextSummary(_ raw: String, maxLength: Int = 2000) -> String {
        var text = raw
        text = replace(text, pattern: #"(?is)<script\b[^>]*>.*?</script>"#, template: "")
        text = replace(text, pattern: #"(?is)<style\b[^>]*>.*?</style>"#, template: "")
        text = replace(text, pattern: #"(?is)<iframe\b[^>]*>.*?</iframe>"#, template: "")
        text = replace(text, pattern: #"(?i)<[^>]+>"#, template: "")
        text = replace(text, pattern: #"!\[([^\]]*)\]\([^)]*\)"#, template: "$1")
        text = replace(text, pattern: #"\[([^\]]+)\]\([^)]*\)"#, template: "$1")
        text = replace(text, pattern: #"(?m)^#{1,6}\s*"#, template: "")
        text = text.replacingOccurrences(of: "```", with: "")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > maxLength {
            let end = text.index(text.startIndex, offsetBy: maxLength)
            text = String(text[..<end]) + "…"
        }
        return text
    }

    public static func containsUnsafeMarkup(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("<script")
            || lower.contains("<iframe")
            || lower.contains("javascript:")
            || lower.contains("<html")
    }

    private static func replace(_ input: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: template)
    }
}

public enum UpdateMinimumOSParser {
    public static func parse(fromReleaseNotes notes: String, fallback: String = UpdateSafetyLimits.defaultMinimumMacOS) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"macOS\s+(\d+(?:\.\d+){0,2})"#, options: .caseInsensitive) else {
            return fallback
        }
        let range = NSRange(notes.startIndex..<notes.endIndex, in: notes)
        guard let match = regex.firstMatch(in: notes, range: range),
              let versionRange = Range(match.range(at: 1), in: notes)
        else {
            return fallback
        }
        return String(notes[versionRange])
    }
}

public enum UpdateByteCountFormatter {
    public static func displayString(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kilobytes = Double(bytes) / 1024
        if kilobytes < 1024 { return String(format: "%.1f KB", kilobytes) }
        let megabytes = kilobytes / 1024
        if megabytes < 1024 { return String(format: "%.1f MB", megabytes) }
        return String(format: "%.2f GB", megabytes / 1024)
    }
}
