import Foundation

/// 界面语言（对齐智额语种列表）。
public enum AppLanguage: String, Codable, CaseIterable, Sendable, Identifiable {
    case zhHans = "zh-Hans"
    case en = "en"
    case ja = "ja"
    case ko = "ko"
    case ru = "ru"
    case ar = "ar"
    case fr = "fr"
    case de = "de"
    case es = "es"
    case pt = "pt"

    public var id: String { rawValue }

    /// 语言本名（选择器展示）
    public var nativeName: String {
        switch self {
        case .zhHans: "简体中文"
        case .en: "English"
        case .ja: "日本語"
        case .ko: "한국어"
        case .ru: "Русский"
        case .ar: "العربية"
        case .fr: "Français"
        case .de: "Deutsch"
        case .es: "Español"
        case .pt: "Português"
        }
    }

    public var shortName: String {
        switch self {
        case .zhHans: "中文"
        case .en: "EN"
        case .ja: "JP"
        case .ko: "KR"
        case .ru: "RU"
        case .ar: "AR"
        case .fr: "FR"
        case .de: "DE"
        case .es: "ES"
        case .pt: "PT"
        }
    }

    public static var `default`: AppLanguage { .zhHans }

    public static func resolve(_ raw: String?) -> AppLanguage {
        guard let raw, let lang = AppLanguage(rawValue: raw) else { return .default }
        return lang
    }
}
