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
        "home.usage": [
            .zhHans: "用量", .en: "Usage", .ja: "使用量", .ko: "사용량",
            .ru: "Расход", .ar: "الاستخدام", .fr: "Utilisation", .de: "Nutzung",
            .es: "Uso", .pt: "Uso",
        ],
        "usage.title": [
            .zhHans: "用量统计", .en: "Usage", .ja: "使用量", .ko: "사용량 통계",
            .ru: "Статистика расхода", .ar: "إحصاءات الاستخدام", .fr: "Statistiques d’utilisation", .de: "Nutzungsstatistik",
            .es: "Estadísticas de uso", .pt: "Estatísticas de uso",
        ],
        "usage.day": [
            .zhHans: "天", .en: "Day", .ja: "日", .ko: "일",
            .ru: "День", .ar: "اليوم", .fr: "Jour", .de: "Tag",
            .es: "Día", .pt: "Dia",
        ],
        "usage.week": [
            .zhHans: "周", .en: "Week", .ja: "週", .ko: "주",
            .ru: "Неделя", .ar: "الأسبوع", .fr: "Semaine", .de: "Woche",
            .es: "Semana", .pt: "Semana",
        ],
        "usage.month": [
            .zhHans: "月", .en: "Month", .ja: "月", .ko: "월",
            .ru: "Месяц", .ar: "الشهر", .fr: "Mois", .de: "Monat",
            .es: "Mes", .pt: "Mês",
        ],
        "usage.previous": [
            .zhHans: "上一周期", .en: "Previous period", .ja: "前の期間", .ko: "이전 기간",
            .ru: "Предыдущий период", .ar: "الفترة السابقة", .fr: "Période précédente", .de: "Vorheriger Zeitraum",
            .es: "Periodo anterior", .pt: "Período anterior",
        ],
        "usage.next": [
            .zhHans: "下一周期", .en: "Next period", .ja: "次の期間", .ko: "다음 기간",
            .ru: "Следующий период", .ar: "الفترة التالية", .fr: "Période suivante", .de: "Nächster Zeitraum",
            .es: "Periodo siguiente", .pt: "Próximo período",
        ],
        "usage.current_day": [
            .zhHans: "今天", .en: "Today", .ja: "今日", .ko: "오늘",
            .ru: "Сегодня", .ar: "اليوم", .fr: "Aujourd’hui", .de: "Heute",
            .es: "Hoy", .pt: "Hoje",
        ],
        "usage.current_week": [
            .zhHans: "本周", .en: "This week", .ja: "今週", .ko: "이번 주",
            .ru: "Эта неделя", .ar: "هذا الأسبوع", .fr: "Cette semaine", .de: "Diese Woche",
            .es: "Esta semana", .pt: "Esta semana",
        ],
        "usage.current_month": [
            .zhHans: "本月", .en: "This month", .ja: "今月", .ko: "이번 달",
            .ru: "Этот месяц", .ar: "هذا الشهر", .fr: "Ce mois", .de: "Dieser Monat",
            .es: "Este mes", .pt: "Este mês",
        ],
        "usage.provider_quality": [
            .zhHans: "接口统计", .en: "Provider data", .ja: "API 集計", .ko: "API 집계",
            .ru: "Данные сервиса", .ar: "بيانات المزوّد", .fr: "Données fournisseur", .de: "Anbieterdaten",
            .es: "Datos del proveedor", .pt: "Dados do provedor",
        ],
        "usage.estimated_quality": [
            .zhHans: "余额估算", .en: "Balance estimate", .ja: "残高推定", .ko: "잔액 추정",
            .ru: "Оценка по балансу", .ar: "تقدير من الرصيد", .fr: "Estimation du solde", .de: "Saldo-Schätzung",
            .es: "Estimación por saldo", .pt: "Estimativa pelo saldo",
        ],
        "usage.mixed_quality": [
            .zhHans: "混合统计", .en: "Mixed data", .ja: "混合集計", .ko: "혼합 집계",
            .ru: "Смешанные данные", .ar: "بيانات مختلطة", .fr: "Données mixtes", .de: "Gemischte Daten",
            .es: "Datos mixtos", .pt: "Dados mistos",
        ],
        "usage.accounts_count": [
            .zhHans: "%d 个账号", .en: "%d accounts", .ja: "%d アカウント", .ko: "%d개 계정",
            .ru: "Аккаунтов: %d", .ar: "%d حسابات", .fr: "%d comptes", .de: "%d Konten",
            .es: "%d cuentas", .pt: "%d contas",
        ],
        "usage.no_accounts": [
            .zhHans: "还没有可统计的账号", .en: "No accounts to track yet", .ja: "集計できるアカウントがありません", .ko: "집계할 계정이 없습니다",
            .ru: "Нет аккаунтов для учёта", .ar: "لا توجد حسابات لتتبعها", .fr: "Aucun compte à suivre", .de: "Noch keine Konten zur Auswertung",
            .es: "Aún no hay cuentas para medir", .pt: "Ainda não há contas para acompanhar",
        ],
        "usage.open_settings": [
            .zhHans: "前往设置", .en: "Open Settings", .ja: "設定を開く", .ko: "설정 열기",
            .ru: "Открыть настройки", .ar: "فتح الإعدادات", .fr: "Ouvrir les réglages", .de: "Einstellungen öffnen",
            .es: "Abrir ajustes", .pt: "Abrir ajustes",
        ],
        "usage.baseline_only": [
            .zhHans: "已开始记录。下次成功刷新后会显示消费差额。", .en: "Tracking has started. Usage appears after the next successful refresh.", .ja: "記録を開始しました。次回の更新後に使用差分を表示します。", .ko: "기록을 시작했습니다. 다음 새로고침 후 사용량이 표시됩니다.",
            .ru: "Учёт начат. Расход появится после следующего успешного обновления.", .ar: "بدأ التتبع. سيظهر الاستخدام بعد التحديث الناجح التالي.", .fr: "Le suivi a commencé. L’utilisation apparaîtra après la prochaine actualisation réussie.", .de: "Die Aufzeichnung läuft. Die Nutzung erscheint nach der nächsten erfolgreichen Aktualisierung.",
            .es: "El seguimiento ha comenzado. El uso aparecerá tras la próxima actualización correcta.", .pt: "O acompanhamento começou. O uso aparecerá após a próxima atualização bem-sucedida.",
        ],
        "usage.no_spend": [
            .zhHans: "这个周期还没有记录到消费", .en: "No usage recorded in this period", .ja: "この期間の使用記録はありません", .ko: "이 기간에 기록된 사용량이 없습니다",
            .ru: "За этот период расход не зафиксирован", .ar: "لم يُسجّل استخدام في هذه الفترة", .fr: "Aucune utilisation enregistrée sur cette période", .de: "In diesem Zeitraum wurde keine Nutzung erfasst",
            .es: "No se registró uso en este periodo", .pt: "Nenhum uso registrado neste período",
        ],
        "usage.save_failed": [
            .zhHans: "用量记录保存失败，余额显示不受影响", .en: "Usage history could not be saved. Balances are unaffected.", .ja: "使用履歴を保存できませんでした。残高表示には影響しません。", .ko: "사용 기록을 저장하지 못했습니다. 잔액 표시는 유지됩니다.",
            .ru: "Не удалось сохранить историю расхода. Баланс отображается как обычно.", .ar: "تعذّر حفظ سجل الاستخدام. عرض الأرصدة لم يتأثر.", .fr: "Impossible d’enregistrer l’historique. Les soldes restent disponibles.", .de: "Der Nutzungsverlauf konnte nicht gespeichert werden. Salden sind nicht betroffen.",
            .es: "No se pudo guardar el historial. Los saldos no se ven afectados.", .pt: "Não foi possível salvar o histórico. Os saldos não foram afetados.",
        ],
        "usage.boundary_hint": [
            .zhHans: "包含跨日离线区间，金额归入后一次刷新日期", .en: "Includes an offline day boundary; the delta is assigned to the later refresh date.", .ja: "日付をまたぐ未更新区間を含み、差額は後の更新日に計上されます。", .ko: "날짜 경계를 넘긴 오프라인 구간이 포함되어 차액은 이후 새로고침 날짜에 반영됩니다.",
            .ru: "Есть офлайн-интервал через границу дня; разница отнесена к дате позднего обновления.", .ar: "تتضمن فترة دون اتصال عبر منتصف الليل؛ أُضيف الفرق إلى تاريخ التحديث اللاحق.", .fr: "Inclut une période hors ligne à cheval sur minuit ; l’écart est affecté à la date d’actualisation suivante.", .de: "Enthält eine Offline-Phase über Mitternacht; die Differenz zählt zum späteren Aktualisierungsdatum.",
            .es: "Incluye un intervalo sin conexión entre días; la diferencia se asigna a la fecha posterior.", .pt: "Inclui um intervalo offline entre dias; a diferença é atribuída à data posterior.",
        ],
        "usage.last_updated": [
            .zhHans: "最后记录", .en: "Last recorded", .ja: "最終記録", .ko: "마지막 기록",
            .ru: "Последняя запись", .ar: "آخر تسجيل", .fr: "Dernier relevé", .de: "Zuletzt erfasst",
            .es: "Último registro", .pt: "Último registro",
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
