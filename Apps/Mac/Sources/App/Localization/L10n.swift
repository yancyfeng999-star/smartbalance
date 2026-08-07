import Foundation
import Domain

/// 轻量界面文案表。缺键回退简体中文。
@MainActor
final class L10n: ObservableObject {
    static let shared = L10n()

    @Published private(set) var language: AppLanguage = .zhHans
    /// 变更时 SwiftUI 可依赖刷新
    @Published private(set) var revision: Int = 0

    func setLanguage(_ lang: AppLanguage) {
        guard language != lang else { return }
        language = lang
        revision &+= 1
    }

    func t(_ key: String) -> String {
        if let s = table[key]?[language] { return s }
        if let s = table[key]?[.zhHans] { return s }
        if let s = table[key]?[.en] { return s }
        return key
    }

    private typealias Row = [AppLanguage: String]

    private let table: [String: Row] = [
        "settings.title": [
            .zhHans: "设置", .en: "Settings", .ja: "設定", .ko: "설정",
            .ru: "Настройки", .ar: "الإعدادات", .fr: "Réglages", .de: "Einstellungen",
            .es: "Ajustes", .pt: "Ajustes",
        ],
        "settings.back": [
            .zhHans: "返回", .en: "Back", .ja: "戻る", .ko: "뒤로",
            .ru: "Назад", .ar: "رجوع", .fr: "Retour", .de: "Zurück",
            .es: "Volver", .pt: "Voltar",
        ],
        "settings.done": [
            .zhHans: "完成", .en: "Done", .ja: "完了", .ko: "완료",
            .ru: "Готово", .ar: "تم", .fr: "OK", .de: "Fertig",
            .es: "Listo", .pt: "Concluir",
        ],
        "settings.appearance": [
            .zhHans: "外观", .en: "Appearance", .ja: "外観", .ko: "모양",
            .ru: "Оформление", .ar: "المظهر", .fr: "Apparence", .de: "Darstellung",
            .es: "Apariencia", .pt: "Aparência",
        ],
        "settings.choose_theme": [
            .zhHans: "选择主题", .en: "Choose theme", .ja: "テーマを選択", .ko: "테마 선택",
            .ru: "Выбор темы", .ar: "اختر المظهر", .fr: "Choisir le thème", .de: "Thema wählen",
            .es: "Elegir tema", .pt: "Escolher tema",
        ],
        "settings.theme.light": [
            .zhHans: "浅色", .en: "Light", .ja: "ライト", .ko: "라이트",
            .ru: "Светлая", .ar: "فاتح", .fr: "Clair", .de: "Hell",
            .es: "Claro", .pt: "Claro",
        ],
        "settings.theme.dark": [
            .zhHans: "深色", .en: "Dark", .ja: "ダーク", .ko: "다크",
            .ru: "Тёмная", .ar: "داكن", .fr: "Sombre", .de: "Dunkel",
            .es: "Oscuro", .pt: "Escuro",
        ],
        "settings.theme.system": [
            .zhHans: "跟随系统", .en: "System", .ja: "システム", .ko: "시스템",
            .ru: "Система", .ar: "النظام", .fr: "Système", .de: "System",
            .es: "Sistema", .pt: "Sistema",
        ],
        "settings.language": [
            .zhHans: "语言", .en: "Language", .ja: "言語", .ko: "언어",
            .ru: "Язык", .ar: "اللغة", .fr: "Langue", .de: "Sprache",
            .es: "Idioma", .pt: "Idioma",
        ],
        "settings.language_sub": [
            .zhHans: "切换界面显示语言", .en: "Interface language", .ja: "表示言語を切り替え", .ko: "인터페이스 언어",
            .ru: "Язык интерфейса", .ar: "لغة الواجهة", .fr: "Langue de l’interface", .de: "Oberflächensprache",
            .es: "Idioma de la interfaz", .pt: "Idioma da interface",
        ],
        "settings.language_hint": [
            .zhHans: "立即生效，无需重启", .en: "Applies immediately", .ja: "すぐに反映（再起動不要）", .ko: "즉시 적용, 재시작 불필요",
            .ru: "Применяется сразу", .ar: "يسري فورًا", .fr: "Prend effet immédiatement", .de: "Sofort wirksam",
            .es: "Se aplica al instante", .pt: "Aplica imediatamente",
        ],
        "settings.api": [
            .zhHans: "API 账号", .en: "API accounts", .ja: "API アカウント", .ko: "API 계정",
            .ru: "API-аккаунты", .ar: "حسابات API", .fr: "Comptes API", .de: "API-Konten",
            .es: "Cuentas API", .pt: "Contas API",
        ],
        "settings.alerts": [
            .zhHans: "报警通知", .en: "Alerts", .ja: "通知", .ko: "알림",
            .ru: "Оповещения", .ar: "التنبيهات", .fr: "Alertes", .de: "Hinweise",
            .es: "Alertas", .pt: "Alertas",
        ],
        "home.open_dashboard": [
            .zhHans: "打开后台", .en: "Dashboard", .ja: "コンソール", .ko: "콘솔",
            .ru: "Консоль", .ar: "لوحة التحكم", .fr: "Console", .de: "Konsole",
            .es: "Consola", .pt: "Console",
        ],
        "home.settings": [
            .zhHans: "设置", .en: "Settings", .ja: "設定", .ko: "설정",
            .ru: "Настройки", .ar: "الإعدادات", .fr: "Réglages", .de: "Einstellungen",
            .es: "Ajustes", .pt: "Ajustes",
        ],
        "home.quit": [
            .zhHans: "退出应用", .en: "Quit", .ja: "終了", .ko: "종료",
            .ru: "Выход", .ar: "خروج", .fr: "Quitter", .de: "Beenden",
            .es: "Salir", .pt: "Sair",
        ],
        "home.sort_mode": [
            .zhHans: "排序模式 · 用右侧箭头调整顺序", .en: "Reorder · use arrows on the right",
            .ja: "並べ替え · 右の矢印", .ko: "정렬 · 오른쪽 화살표",
            .ru: "Порядок · стрелки справа", .ar: "الترتيب · الأسهم يمينًا",
            .fr: "Réordonner · flèches à droite", .de: "Sortieren · Pfeile rechts",
            .es: "Reordenar · flechas a la derecha", .pt: "Reordenar · setas à direita",
        ],
        "common.done": [
            .zhHans: "完成", .en: "Done", .ja: "完了", .ko: "완료",
            .ru: "Готово", .ar: "تم", .fr: "OK", .de: "Fertig",
            .es: "Listo", .pt: "Concluir",
        ],
    ]
}
