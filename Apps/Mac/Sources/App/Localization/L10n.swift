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
        "usage.load_failed": [
            .zhHans: "无法读取用量历史。为保护已有数据，本次暂停记录。", .en: "Usage history could not be read. New samples are paused to protect existing data.", .ja: "使用履歴を読み込めません。既存データを保護するため記録を停止しました。", .ko: "사용 기록을 읽을 수 없습니다. 기존 데이터를 보호하기 위해 기록을 일시 중지했습니다.",
            .ru: "Не удалось прочитать историю расхода. Новые записи приостановлены для защиты данных.", .ar: "تعذّرت قراءة سجل الاستخدام. أُوقف التسجيل مؤقتًا لحماية البيانات الحالية.", .fr: "Impossible de lire l’historique. Les nouveaux relevés sont suspendus pour protéger les données.", .de: "Der Nutzungsverlauf konnte nicht gelesen werden. Neue Erfassungen sind zum Schutz der Daten pausiert.",
            .es: "No se pudo leer el historial. Las nuevas muestras están pausadas para proteger los datos.", .pt: "Não foi possível ler o histórico. Novos registros foram pausados para proteger os dados.",
        ],
        "usage.history_recovered": [
            .zhHans: "用量历史已损坏并完成备份，现已重新开始记录。", .en: "Damaged usage history was backed up. Tracking has restarted.", .ja: "破損した使用履歴をバックアップし、記録を再開しました。", .ko: "손상된 사용 기록을 백업하고 기록을 다시 시작했습니다.",
            .ru: "Повреждённая история сохранена в резервную копию. Учёт начат заново.", .ar: "تم نسخ سجل الاستخدام التالف احتياطيًا وبدأ التسجيل من جديد.", .fr: "L’historique endommagé a été sauvegardé. Le suivi a redémarré.", .de: "Der beschädigte Nutzungsverlauf wurde gesichert. Die Erfassung wurde neu gestartet.",
            .es: "Se guardó una copia del historial dañado. El seguimiento se reinició.", .pt: "O histórico danificado foi copiado. O acompanhamento foi reiniciado.",
        ],
        "usage.points_count": [
            .zhHans: "%d 个数据点", .en: "%d data points", .ja: "%d データ点", .ko: "%d개 데이터 포인트",
            .ru: "Точек данных: %d", .ar: "%d نقاط بيانات", .fr: "%d points de données", .de: "%d Datenpunkte",
            .es: "%d puntos de datos", .pt: "%d pontos de dados",
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
        "refresh.last_prefix": [
            .zhHans: "刷新", .en: "Refreshed", .ja: "更新", .ko: "새로고침",
            .ru: "Обновлено", .ar: "تم التحديث", .fr: "Actualisé", .de: "Aktualisiert",
            .es: "Actualizado", .pt: "Atualizado",
        ],
        "refresh.running": [
            .zhHans: "查询中…", .en: "Refreshing…", .ja: "更新中…", .ko: "새로고침 중…",
            .ru: "Обновление…", .ar: "جارٍ التحديث…", .fr: "Actualisation…", .de: "Aktualisieren…",
            .es: "Actualizando…", .pt: "A atualizar…",
        ],
        "refresh.cancelled_kept_last": [
            .zhHans: "已取消，已保留上次结果", .en: "Cancelled. Last result kept.", .ja: "キャンセルしました。前回の結果を保持します。", .ko: "취소했습니다. 이전 결과를 유지합니다.",
            .ru: "Отменено. Сохранён прошлый результат.", .ar: "أُلغي. تم الإبقاء على آخر نتيجة.", .fr: "Annulé. Dernier résultat conservé.", .de: "Abgebrochen. Letztes Ergebnis behalten.",
            .es: "Cancelado. Se conserva el último resultado.", .pt: "Cancelado. O último resultado foi mantido.",
        ],
        "refresh.partial_failed": [
            .zhHans: "部分账号刷新失败", .en: "Some accounts failed to refresh", .ja: "一部のアカウントの更新に失敗", .ko: "일부 계정 새로고침 실패",
            .ru: "Часть аккаунтов не обновилась", .ar: "فشل تحديث بعض الحسابات", .fr: "Échec partiel de l’actualisation", .de: "Einige Konten konnten nicht aktualisiert werden",
            .es: "Algunas cuentas no se actualizaron", .pt: "Algumas contas falharam ao atualizar",
        ],
        "refresh.failed": [
            .zhHans: "刷新失败", .en: "Refresh failed", .ja: "更新に失敗", .ko: "새로고침 실패",
            .ru: "Не удалось обновить", .ar: "فشل التحديث", .fr: "Échec de l’actualisation", .de: "Aktualisierung fehlgeschlagen",
            .es: "Error al actualizar", .pt: "Falha ao atualizar",
        ],
        "refresh.cancel": [
            .zhHans: "取消刷新", .en: "Cancel refresh", .ja: "更新をキャンセル", .ko: "새로고침 취소",
            .ru: "Отменить обновление", .ar: "إلغاء التحديث", .fr: "Annuler l’actualisation", .de: "Aktualisierung abbrechen",
            .es: "Cancelar actualización", .pt: "Cancelar atualização",
        ],
        "refresh.action": [
            .zhHans: "刷新全部", .en: "Refresh all", .ja: "すべて更新", .ko: "모두 새로고침",
            .ru: "Обновить всё", .ar: "تحديث الكل", .fr: "Tout actualiser", .de: "Alle aktualisieren",
            .es: "Actualizar todo", .pt: "Atualizar tudo",
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
        "onboarding.title": [
            .zhHans: "开始使用智余", .en: "Get started with SmartBalance", .ja: "智余を始める", .ko: "智余 시작하기",
            .ru: "Начало работы с 智余", .ar: "ابدأ مع 智余", .fr: "Démarrer avec 智余", .de: "Mit 智余 starten",
            .es: "Empezar con 智余", .pt: "Começar com 智余",
        ],
        "onboarding.step.privacy": [
            .zhHans: "隐私说明", .en: "Privacy", .ja: "プライバシー", .ko: "개인정보",
            .ru: "Конфиденциальность", .ar: "الخصوصية", .fr: "Confidentialité", .de: "Datenschutz",
            .es: "Privacidad", .pt: "Privacidade",
        ],
        "onboarding.step.compatibility": [
            .zhHans: "环境检查", .en: "Environment", .ja: "環境チェック", .ko: "환경 확인",
            .ru: "Проверка среды", .ar: "فحص البيئة", .fr: "Environnement", .de: "Umgebung",
            .es: "Entorno", .pt: "Ambiente",
        ],
        "onboarding.step.provider": [
            .zhHans: "添加渠道", .en: "Add a provider", .ja: "チャネル追加", .ko: "채널 추가",
            .ru: "Добавить канал", .ar: "إضافة مزوّد", .fr: "Ajouter un canal", .de: "Kanal hinzufügen",
            .es: "Añadir proveedor", .pt: "Adicionar provedor",
        ],
        "onboarding.step.notifications": [
            .zhHans: "通知说明", .en: "Notifications", .ja: "通知", .ko: "알림",
            .ru: "Уведомления", .ar: "الإشعارات", .fr: "Notifications", .de: "Mitteilungen",
            .es: "Notificaciones", .pt: "Notificações",
        ],
        "onboarding.privacy.title": [
            .zhHans: "数据留在这台 Mac", .en: "Your data stays on this Mac", .ja: "データはこの Mac に残ります", .ko: "데이터는 이 Mac에 남습니다",
            .ru: "Данные остаются на этом Mac", .ar: "تبقى بياناتك على هذا الـ Mac", .fr: "Vos données restent sur ce Mac", .de: "Ihre Daten bleiben auf diesem Mac",
            .es: "Tus datos se quedan en este Mac", .pt: "Os seus dados ficam neste Mac",
        ],
        "onboarding.privacy.subtitle": [
            .zhHans: "智余是本机菜单栏工具。开始前请先了解数据如何存放。", .en: "SmartBalance is a local menu-bar tool. Review how data is stored before you start.", .ja: "智余はローカルのメニューバーツールです。開始前にデータの扱いを確認してください。", .ko: "智余는 로컬 메뉴 막대 도구입니다. 시작 전에 데이터 저장 방식을 확인하세요.",
            .ru: "智余 — локальный инструмент в строке меню. Сначала посмотрите, где хранятся данные.", .ar: "智余 أداة محلية في شريط القوائم. راجع كيفية تخزين البيانات قبل البدء.", .fr: "智余 est un outil local dans la barre de menus. Voyez comment les données sont stockées.", .de: "智余 ist ein lokales Menüleisten-Werkzeug. Prüfen Sie zuerst, wo Daten liegen.",
            .es: "智余 es una herramienta local de la barra de menús. Revisa cómo se guardan los datos.", .pt: "智余 é uma ferramenta local da barra de menus. Veja como os dados são guardados.",
        ],
        "onboarding.privacy.local": [
            .zhHans: "设置、用量和日志只写在本机目录。", .en: "Settings, usage, and logs stay in local folders.", .ja: "設定・使用量・ログはローカルフォルダにだけ保存されます。", .ko: "설정, 사용량, 로그는 로컬 폴더에만 저장됩니다.",
            .ru: "Настройки, расход и журналы остаются в локальных папках.", .ar: "تبقى الإعدادات والاستخدام والسجلات في مجلدات محلية.", .fr: "Réglages, usage et journaux restent dans des dossiers locaux.", .de: "Einstellungen, Nutzung und Protokolle bleiben in lokalen Ordnern.",
            .es: "Ajustes, uso y registros se quedan en carpetas locales.", .pt: "Definições, uso e registos ficam em pastas locais.",
        ],
        "onboarding.privacy.no_upload": [
            .zhHans: "没有遥测、云同步或远程诊断上传。", .en: "No telemetry, cloud sync, or remote diagnostics upload.", .ja: "テレメトリ、クラウド同期、遠隔診断の送信はありません。", .ko: "텔레메트리, 클라우드 동기화, 원격 진단 업로드가 없습니다.",
            .ru: "Нет телеметрии, облачной синхронизации и удалённой диагностики.", .ar: "لا توجد قياس عن بُعد أو مزامنة سحابية أو تشخيص عن بُعد.", .fr: "Pas de télémétrie, de sync cloud ni d’envoi de diagnostic.", .de: "Keine Telemetrie, keine Cloud-Sync, kein Remote-Diagnose-Upload.",
            .es: "Sin telemetría, sincronización en la nube ni diagnóstico remoto.", .pt: "Sem telemetria, sincronização na nuvem ou diagnóstico remoto.",
        ],
        "onboarding.privacy.keychain": [
            .zhHans: "密钥只进入本机普通钥匙串，不会在此向导里填写。", .en: "Secrets stay in the ordinary local Keychain and are not collected here.", .ja: "秘密情報は通常のローカルキーチェーンに入り、この画面では入力しません。", .ko: "비밀 값은 일반 로컬 키체인에만 들어가며 이 화면에서 받지 않습니다.",
            .ru: "Секреты остаются в обычной локальной связке ключей и здесь не собираются.", .ar: "تبقى الأسرار في سلسلة المفاتيح العادية ولا تُجمع هنا.", .fr: "Les secrets restent dans le trousseau local ordinaire et ne sont pas saisis ici.", .de: "Geheimnisse bleiben in der normalen lokalen Schlüsselkette und werden hier nicht erfasst.",
            .es: "Los secretos quedan en el llavero local normal y no se piden aquí.", .pt: "Os segredos ficam no Porta-chaves local normal e não são pedidos aqui.",
        ],
        "onboarding.privacy.no_secrets": [
            .zhHans: "此向导不收集 API Key、SMTP 密码或远程账号密码。", .en: "This guide does not collect API keys, SMTP passwords, or remote account passwords.", .ja: "この案内では API キー、SMTP パスワード、遠隔アカウントのパスワードは収集しません。", .ko: "이 안내에서는 API 키, SMTP 비밀번호, 원격 계정 비밀번호를 받지 않습니다.",
            .ru: "Это руководство не собирает API-ключи, SMTP-пароли и пароли удалённых аккаунтов.", .ar: "لا يجمع هذا الدليل مفاتيح API أو كلمات مرور SMTP أو حسابات بعيدة.", .fr: "Ce guide ne collecte ni clés API, ni mots de passe SMTP, ni mots de passe distants.", .de: "Dieser Assistent erfasst keine API-Keys, SMTP-Passwörter oder Remote-Kontopasswörter.",
            .es: "Esta guía no recoge claves API, contraseñas SMTP ni contraseñas remotas.", .pt: "Este guia não recolhe chaves API, palavras-passe SMTP nem palavras-passe remotas.",
        ],
        "onboarding.privacy.continue": [
            .zhHans: "继续", .en: "Continue", .ja: "続ける", .ko: "계속",
            .ru: "Далее", .ar: "متابعة", .fr: "Continuer", .de: "Weiter",
            .es: "Continuar", .pt: "Continuar",
        ],
        "onboarding.compat.title": [
            .zhHans: "这台 Mac 的环境", .en: "This Mac’s environment", .ja: "この Mac の環境", .ko: "이 Mac의 환경",
            .ru: "Среда этого Mac", .ar: "بيئة هذا الـ Mac", .fr: "Environnement de ce Mac", .de: "Umgebung dieses Mac",
            .es: "Entorno de este Mac", .pt: "Ambiente deste Mac",
        ],
        "onboarding.compat.subtitle": [
            .zhHans: "这些是本机诊断，不是渠道余额失败。可稍后在设置里再看。", .en: "These are local diagnostics, not provider balance failures. You can review them later in Settings.", .ja: "これはローカル診断であり、チャネル残高の失敗ではありません。後で設定から確認できます。", .ko: "로컬 진단이며 채널 잔액 실패가 아닙니다. 나중에 설정에서 다시 볼 수 있습니다.",
            .ru: "Это локальная диагностика, а не сбой баланса канала. Позже можно открыть в настройках.", .ar: "هذه فحوصات محلية وليست فشل رصيد المزوّد. يمكنك مراجعتها لاحقًا في الإعدادات.", .fr: "Ce sont des diagnostics locaux, pas des échecs de solde. Vous pourrez les revoir dans Réglages.", .de: "Das sind lokale Diagnosen, keine Kanal-Saldofehler. Später in den Einstellungen prüfbar.",
            .es: "Son diagnósticos locales, no fallos de saldo. Puedes revisarlos luego en Ajustes.", .pt: "São diagnósticos locais, não falhas de saldo. Pode revê-los depois em Ajustes.",
        ],
        "onboarding.compat.continue": [
            .zhHans: "继续", .en: "Continue", .ja: "続ける", .ko: "계속",
            .ru: "Далее", .ar: "متابعة", .fr: "Continuer", .de: "Weiter",
            .es: "Continuar", .pt: "Continuar",
        ],
        "onboarding.compat.later": [
            .zhHans: "稍后处理", .en: "Handle later", .ja: "あとで", .ko: "나중에",
            .ru: "Позже", .ar: "لاحقًا", .fr: "Plus tard", .de: "Später",
            .es: "Más tarde", .pt: "Mais tarde",
        ],
        "onboarding.provider.title": [
            .zhHans: "添加第一个渠道或打开现有配置", .en: "Add your first provider or open an existing setup", .ja: "最初のチャネルを追加、または既存設定を開く", .ko: "첫 채널을 추가하거나 기존 설정을 여세요",
            .ru: "Добавьте первый канал или откройте текущую конфигурацию", .ar: "أضف أول مزوّد أو افتح الإعداد الحالي", .fr: "Ajoutez un premier canal ou ouvrez la config existante", .de: "Ersten Kanal hinzufügen oder bestehende Konfiguration öffnen",
            .es: "Añade el primer proveedor o abre la configuración existente", .pt: "Adicione o primeiro provedor ou abra a configuração existente",
        ],
        "onboarding.provider.subtitle": [
            .zhHans: "没有账号并不代表渠道损坏。在设置里用现有卡片添加平台。", .en: "An empty account list is not a broken provider. Add platforms with the existing Settings cards.", .ja: "アカウントが空でもチャネル故障ではありません。設定の既存カードで追加します。", .ko: "계정이 비어 있다고 채널이 고장난 것은 아닙니다. 설정의 기존 카드에서 추가하세요.",
            .ru: "Пустой список аккаунтов — не поломка канала. Добавляйте платформы в существующих карточках настроек.", .ar: "قائمة الحسابات الفارغة ليست عطلاً. أضف المنصات من بطاقات الإعدادات الحالية.", .fr: "Une liste vide n’est pas un canal cassé. Ajoutez les plateformes via les cartes Réglages existantes.", .de: "Eine leere Kontoliste ist kein defekter Kanal. Plattformen über die vorhandenen Einstellkarten hinzufügen.",
            .es: "Una lista vacía no es un proveedor roto. Añade plataformas con las tarjetas de Ajustes.", .pt: "Uma lista vazia não é um provedor avariado. Adicione plataformas nas fichas de Ajustes.",
        ],
        "onboarding.provider.no_keys": [
            .zhHans: "这里不会要求填写 API Key 或密码。", .en: "This screen will not ask for API keys or passwords.", .ja: "この画面では API キーやパスワードは求めません。", .ko: "이 화면에서는 API 키나 비밀번호를 묻지 않습니다.",
            .ru: "Этот экран не запрашивает API-ключи и пароли.", .ar: "لن يطلب هذا الشاشة مفاتيح API أو كلمات مرور.", .fr: "Cet écran ne demandera ni clés API ni mots de passe.", .de: "Dieser Bildschirm fragt keine API-Keys oder Passwörter ab.",
            .es: "Esta pantalla no pedirá claves API ni contraseñas.", .pt: "Este ecrã não pede chaves API nem palavras-passe.",
        ],
        "onboarding.provider.add": [
            .zhHans: "去设置添加渠道", .en: "Add a provider in Settings", .ja: "設定でチャネルを追加", .ko: "설정에서 채널 추가",
            .ru: "Добавить канал в настройках", .ar: "إضافة مزوّد من الإعدادات", .fr: "Ajouter un canal dans Réglages", .de: "Kanal in Einstellungen hinzufügen",
            .es: "Añadir proveedor en Ajustes", .pt: "Adicionar provedor em Ajustes",
        ],
        "onboarding.provider.existing": [
            .zhHans: "打开现有配置", .en: "Open existing setup", .ja: "既存設定を開く", .ko: "기존 설정 열기",
            .ru: "Открыть текущую конфигурацию", .ar: "فتح الإعداد الحالي", .fr: "Ouvrir la config existante", .de: "Bestehende Konfiguration öffnen",
            .es: "Abrir configuración existente", .pt: "Abrir configuração existente",
        ],
        "onboarding.provider.continue": [
            .zhHans: "暂不添加", .en: "Not now", .ja: "今は追加しない", .ko: "지금은 건너뛰기",
            .ru: "Пока не добавлять", .ar: "ليس الآن", .fr: "Pas maintenant", .de: "Jetzt nicht",
            .es: "Ahora no", .pt: "Agora não",
        ],
        "onboarding.notify.title": [
            .zhHans: "可选：开启 Mac 通知", .en: "Optional: enable Mac notifications", .ja: "任意：Mac 通知を許可", .ko: "선택: Mac 알림 켜기",
            .ru: "По желанию: уведомления Mac", .ar: "اختياري: تفعيل إشعارات Mac", .fr: "Facultatif : activer les notifications Mac", .de: "Optional: Mac-Mitteilungen aktivieren",
            .es: "Opcional: activar notificaciones de Mac", .pt: "Opcional: ativar notificações do Mac",
        ],
        "onboarding.notify.subtitle": [
            .zhHans: "余额报警可用 Mac 通知。未授权不是渠道失败，可跳过并稍后在设置里开启。", .en: "Balance alerts can use Mac notifications. Not authorizing is not a provider failure; skip and enable later in Settings.", .ja: "残高アラートに Mac 通知を使えます。未許可はチャネル故障ではありません。スキップして後で設定から有効化できます。", .ko: "잔액 알림에 Mac 알림을 쓸 수 있습니다. 허용하지 않은 것은 채널 실패가 아니며 나중에 설정에서 켤 수 있습니다.",
            .ru: "Оповещения о балансе могут использовать уведомления Mac. Отказ — не сбой канала; можно пропустить и включить позже.", .ar: "يمكن لتنبيهات الرصيد استخدام إشعارات Mac. عدم التفويض ليس فشل مزوّد؛ يمكنك التخطي والتفعيل لاحقًا.", .fr: "Les alertes de solde peuvent utiliser les notifications Mac. Ne pas autoriser n’est pas un échec de canal.", .de: "Saldo-Hinweise können Mac-Mitteilungen nutzen. Keine Freigabe ist kein Kanalfehler.",
            .es: "Las alertas de saldo pueden usar notificaciones de Mac. No autorizar no es un fallo del proveedor.", .pt: "Os alertas de saldo podem usar notificações do Mac. Não autorizar não é falha do provedor.",
        ],
        "onboarding.notify.optional": [
            .zhHans: "只有你点「开启」时才会向系统请求通知权限。", .en: "The system prompt appears only if you tap Enable.", .ja: "「許可する」を押したときだけシステムに通知許可を求めます。", .ko: "켜기를 누를 때만 시스템에 알림 권한을 요청합니다.",
            .ru: "Системный запрос появится, только если вы нажмёте «Включить».", .ar: "يظهر طلب النظام فقط إذا ضغطت على تفعيل.", .fr: "La demande système n’apparaît que si vous appuyez sur Activer.", .de: "Die Systemabfrage erscheint nur, wenn Sie Aktivieren tippen.",
            .es: "El aviso del sistema solo aparece si pulsas Activar.", .pt: "O pedido do sistema só aparece se tocar em Ativar.",
        ],
        "onboarding.notify.enable": [
            .zhHans: "开启通知", .en: "Enable notifications", .ja: "通知を許可", .ko: "알림 켜기",
            .ru: "Включить уведомления", .ar: "تفعيل الإشعارات", .fr: "Activer les notifications", .de: "Mitteilungen aktivieren",
            .es: "Activar notificaciones", .pt: "Ativar notificações",
        ],
        "onboarding.notify.skip": [
            .zhHans: "跳过", .en: "Skip", .ja: "スキップ", .ko: "건너뛰기",
            .ru: "Пропустить", .ar: "تخطي", .fr: "Ignorer", .de: "Überspringen",
            .es: "Omitir", .pt: "Ignorar",
        ],
        "compat.title": [
            .zhHans: "兼容性与环境", .en: "Compatibility", .ja: "互換性と環境", .ko: "호환성 및 환경",
            .ru: "Совместимость", .ar: "التوافق", .fr: "Compatibilité", .de: "Kompatibilität",
            .es: "Compatibilidad", .pt: "Compatibilidade",
        ],
        "compat.loading": [
            .zhHans: "正在检查本机环境…", .en: "Checking this Mac…", .ja: "この Mac を確認しています…", .ko: "이 Mac을 확인하는 중…",
            .ru: "Проверка этого Mac…", .ar: "جارٍ فحص هذا الـ Mac…", .fr: "Vérification de ce Mac…", .de: "Dieser Mac wird geprüft…",
            .es: "Comprobando este Mac…", .pt: "A verificar este Mac…",
        ],
        "compat.corrupt_state": [
            .zhHans: "首次启动状态文件已损坏。设置未被清空。", .en: "The first-launch state file is damaged. Settings were not wiped.", .ja: "初回起動の状態ファイルが壊れています。設定は消去していません。", .ko: "최초 실행 상태 파일이 손상되었습니다. 설정은 지우지 않았습니다.",
            .ru: "Файл состояния первого запуска повреждён. Настройки не очищены.", .ar: "ملف حالة التشغيل الأول تالف. لم تُمسح الإعدادات.", .fr: "Le fichier d’état du premier lancement est endommagé. Les réglages n’ont pas été effacés.", .de: "Die Erststart-Datei ist beschädigt. Einstellungen wurden nicht gelöscht.",
            .es: "El archivo de primer arranque está dañado. No se borraron los ajustes.", .pt: "O ficheiro do primeiro arranque está danificado. As definições não foram apagadas.",
        ],
        "compat.corrupt_state_detail": [
            .zhHans: "请先看环境检查。账号配置仍在设置里，不会被当成空安装。", .en: "Review the environment checks first. Existing accounts stay in Settings and are not treated as a blank install.", .ja: "まず環境チェックを確認してください。既存アカウントは設定に残り、空のインストール扱いしません。", .ko: "먼저 환경 확인을 보세요. 기존 계정은 설정에 남아 빈 설치로 취급하지 않습니다.",
            .ru: "Сначала посмотрите проверки среды. Существующие аккаунты остаются в настройках.", .ar: "راجع فحوصات البيئة أولاً. تبقى الحسابات الحالية في الإعدادات.", .fr: "Consultez d’abord les contrôles. Les comptes existants restent dans Réglages.", .de: "Prüfen Sie zuerst die Umgebung. Vorhandene Konten bleiben in den Einstellungen.",
            .es: "Revisa primero el entorno. Las cuentas existentes siguen en Ajustes.", .pt: "Reveja primeiro o ambiente. As contas existentes ficam em Ajustes.",
        ],
        "compat.open_settings": [
            .zhHans: "打开设置", .en: "Open Settings", .ja: "設定を開く", .ko: "설정 열기",
            .ru: "Открыть настройки", .ar: "فتح الإعدادات", .fr: "Ouvrir les réglages", .de: "Einstellungen öffnen",
            .es: "Abrir ajustes", .pt: "Abrir ajustes",
        ],
        "compat.continue_home": [
            .zhHans: "进入首页", .en: "Go to Home", .ja: "ホームへ", .ko: "홈으로",
            .ru: "На главную", .ar: "إلى الصفحة الرئيسية", .fr: "Aller à l’accueil", .de: "Zur Startseite",
            .es: "Ir al inicio", .pt: "Ir para o início",
        ],
        "compat.refresh": [
            .zhHans: "重新检查", .en: "Recheck", .ja: "再チェック", .ko: "다시 확인",
            .ru: "Проверить снова", .ar: "إعادة الفحص", .fr: "Revérifier", .de: "Erneut prüfen",
            .es: "Volver a comprobar", .pt: "Verificar de novo",
        ],
        "settings.compatibility": [
            .zhHans: "兼容性", .en: "Compatibility", .ja: "互換性", .ko: "호환성",
            .ru: "Совместимость", .ar: "التوافق", .fr: "Compatibilité", .de: "Kompatibilität",
            .es: "Compatibilidad", .pt: "Compatibilidade",
        ],
        "settings.compatibility_sub": [
            .zhHans: "查看本机环境与权限", .en: "View this Mac’s environment and permissions", .ja: "この Mac の環境と権限を見る", .ko: "이 Mac의 환경과 권한 보기",
            .ru: "Среда и разрешения этого Mac", .ar: "عرض بيئة هذا الـ Mac وأذوناته", .fr: "Voir l’environnement et les autorisations", .de: "Umgebung und Berechtigungen anzeigen",
            .es: "Ver entorno y permisos de este Mac", .pt: "Ver ambiente e permissões deste Mac",
        ],
        "settings.compatibility_sub.ok": [
            .zhHans: "未发现阻断问题", .en: "No blocking issues", .ja: "重大な問題はありません", .ko: "차단 문제 없음",
            .ru: "Блокирующих проблем нет", .ar: "لا توجد مشكلات حاجبة", .fr: "Aucun problème bloquant", .de: "Keine blockierenden Probleme",
            .es: "Sin problemas bloqueantes", .pt: "Sem problemas bloqueantes",
        ],
        "settings.compatibility_sub.blocked": [
            .zhHans: "有需要处理的环境问题", .en: "Environment issues need attention", .ja: "対応が必要な環境の問題があります", .ko: "확인이 필요한 환경 문제가 있습니다",
            .ru: "Есть проблемы среды", .ar: "توجد مشكلات بيئة تحتاج إلى انتباه", .fr: "Des problèmes d’environnement demandent attention", .de: "Umgebungsthemen brauchen Aufmerksamkeit",
            .es: "Hay problemas de entorno", .pt: "Há problemas de ambiente",
        ],
        "compat.status.ok": [
            .zhHans: "正常", .en: "OK", .ja: "正常", .ko: "정상",
            .ru: "ОК", .ar: "حسن", .fr: "OK", .de: "OK",
            .es: "OK", .pt: "OK",
        ],
        "compat.status.warning": [
            .zhHans: "注意", .en: "Warning", .ja: "注意", .ko: "주의",
            .ru: "Внимание", .ar: "تحذير", .fr: "Attention", .de: "Hinweis",
            .es: "Aviso", .pt: "Aviso",
        ],
        "compat.status.failed": [
            .zhHans: "失败", .en: "Failed", .ja: "失敗", .ko: "실패",
            .ru: "Ошибка", .ar: "فشل", .fr: "Échec", .de: "Fehler",
            .es: "Error", .pt: "Falha",
        ],
        "compat.status.unknown": [
            .zhHans: "未知", .en: "Unknown", .ja: "不明", .ko: "알 수 없음",
            .ru: "Неизвестно", .ar: "غير معروف", .fr: "Inconnu", .de: "Unbekannt",
            .es: "Desconocido", .pt: "Desconhecido",
        ],
        "compat.check.macos": [
            .zhHans: "macOS 版本", .en: "macOS version", .ja: "macOS バージョン", .ko: "macOS 버전",
            .ru: "Версия macOS", .ar: "إصدار macOS", .fr: "Version de macOS", .de: "macOS-Version",
            .es: "Versión de macOS", .pt: "Versão do macOS",
        ],
        "compat.check.architecture": [
            .zhHans: "处理器架构", .en: "Architecture", .ja: "アーキテクチャ", .ko: "아키텍처",
            .ru: "Архитектура", .ar: "المعمارية", .fr: "Architecture", .de: "Architektur",
            .es: "Arquitectura", .pt: "Arquitetura",
        ],
        "compat.check.applicationSupport": [
            .zhHans: "应用支持目录", .en: "Application Support", .ja: "Application Support", .ko: "Application Support",
            .ru: "Application Support", .ar: "Application Support", .fr: "Application Support", .de: "Application Support",
            .es: "Application Support", .pt: "Application Support",
        ],
        "compat.check.logs": [
            .zhHans: "日志目录", .en: "Log directory", .ja: "ログディレクトリ", .ko: "로그 디렉터리",
            .ru: "Папка журналов", .ar: "مجلد السجلات", .fr: "Dossier des journaux", .de: "Protokollordner",
            .es: "Carpeta de registros", .pt: "Pasta de registos",
        ],
        "compat.check.keychain": [
            .zhHans: "普通钥匙串", .en: "Ordinary Keychain", .ja: "通常のキーチェーン", .ko: "일반 키체인",
            .ru: "Обычная связка ключей", .ar: "سلسلة المفاتيح العادية", .fr: "Trousseau ordinaire", .de: "Normale Schlüsselkette",
            .es: "Llavero ordinario", .pt: "Porta-chaves normal",
        ],
        "compat.check.notifications": [
            .zhHans: "通知授权", .en: "Notification authorization", .ja: "通知の許可", .ko: "알림 권한",
            .ru: "Разрешение уведомлений", .ar: "تفويض الإشعارات", .fr: "Autorisation des notifications", .de: "Mitteilungsfreigabe",
            .es: "Autorización de notificaciones", .pt: "Autorização de notificações",
        ],
        "compat.check.settings": [
            .zhHans: "设置文件", .en: "Settings file", .ja: "設定ファイル", .ko: "설정 파일",
            .ru: "Файл настроек", .ar: "ملف الإعدادات", .fr: "Fichier des réglages", .de: "Einstellungsdatei",
            .es: "Archivo de ajustes", .pt: "Ficheiro de definições",
        ],
        "compat.check.usageHistory": [
            .zhHans: "用量历史", .en: "Usage history", .ja: "使用履歴", .ko: "사용 기록",
            .ru: "История расхода", .ar: "سجل الاستخدام", .fr: "Historique d’utilisation", .de: "Nutzungsverlauf",
            .es: "Historial de uso", .pt: "Histórico de uso",
        ],
        "compat.check.schema": [
            .zhHans: "设置 schema", .en: "Settings schema", .ja: "設定スキーマ", .ko: "설정 스키마",
            .ru: "Схема настроек", .ar: "مخطط الإعدادات", .fr: "Schéma des réglages", .de: "Einstellungsschema",
            .es: "Esquema de ajustes", .pt: "Esquema de definições",
        ],
        "compat.macos.ok": [
            .zhHans: "系统版本满足最低要求。", .en: "This macOS version meets the minimum requirement.", .ja: "この macOS は最低要件を満たしています。", .ko: "이 macOS 버전은 최소 요구 사항을 충족합니다.",
            .ru: "Эта версия macOS соответствует минимуму.", .ar: "إصدار macOS هذا يلبي الحد الأدنى.", .fr: "Cette version de macOS satisfait le minimum.", .de: "Diese macOS-Version erfüllt die Mindestanforderung.",
            .es: "Esta versión de macOS cumple el mínimo.", .pt: "Esta versão do macOS cumpre o mínimo.",
        ],
        "compat.macos.unsupported": [
            .zhHans: "系统版本过低，智余需要 macOS 15 或更高。", .en: "This macOS version is too old. SmartBalance needs macOS 15 or later.", .ja: "macOS が古すぎます。智余には macOS 15 以降が必要です。", .ko: "macOS가 너무 낮습니다. 智余는 macOS 15 이상이 필요합니다.",
            .ru: "Версия macOS слишком старая. Нужен macOS 15 или новее.", .ar: "إصدار macOS قديم جدًا. تحتاج 智余 إلى macOS 15 أو أحدث.", .fr: "Cette version de macOS est trop ancienne. 智余 exige macOS 15 ou plus.", .de: "Diese macOS-Version ist zu alt. 智余 braucht macOS 15 oder neuer.",
            .es: "Esta versión de macOS es demasiado antigua. 智余 necesita macOS 15 o posterior.", .pt: "Esta versão do macOS é demasiado antiga. 智余 precisa de macOS 15 ou posterior.",
        ],
        "compat.architecture.appleSilicon": [
            .zhHans: "当前为 Apple 芯片。", .en: "This Mac is Apple silicon.", .ja: "この Mac は Apple シリコンです。", .ko: "이 Mac은 Apple 실리콘입니다.",
            .ru: "Этот Mac на Apple silicon.", .ar: "هذا الـ Mac بمعالج Apple silicon.", .fr: "Ce Mac est Apple silicon.", .de: "Dieser Mac ist Apple Silicon.",
            .es: "Este Mac es Apple silicon.", .pt: "Este Mac é Apple silicon.",
        ],
        "compat.architecture.intel": [
            .zhHans: "当前为 Intel 处理器。", .en: "This Mac is Intel.", .ja: "この Mac は Intel です。", .ko: "이 Mac은 Intel입니다.",
            .ru: "Этот Mac на Intel.", .ar: "هذا الـ Mac بمعالج Intel.", .fr: "Ce Mac est Intel.", .de: "Dieser Mac ist Intel.",
            .es: "Este Mac es Intel.", .pt: "Este Mac é Intel.",
        ],
        "compat.architecture.unknown": [
            .zhHans: "未能识别处理器架构。", .en: "The processor architecture could not be identified.", .ja: "プロセッサ構成を識別できませんでした。", .ko: "프로세서 아키텍처를 확인하지 못했습니다.",
            .ru: "Не удалось определить архитектуру процессора.", .ar: "تعذّر التعرف على معمارية المعالج.", .fr: "Impossible d’identifier l’architecture du processeur.", .de: "Die Prozessorarchitektur konnte nicht erkannt werden.",
            .es: "No se pudo identificar la arquitectura.", .pt: "Não foi possível identificar a arquitetura.",
        ],
        "compat.appSupport.ok": [
            .zhHans: "Application Support 可写。", .en: "Application Support is writable.", .ja: "Application Support に書き込めます。", .ko: "Application Support에 쓸 수 있습니다.",
            .ru: "Application Support доступен для записи.", .ar: "Application Support قابل للكتابة.", .fr: "Application Support est accessible en écriture.", .de: "Application Support ist beschreibbar.",
            .es: "Application Support es escribible.", .pt: "Application Support é gravável.",
        ],
        "compat.appSupport.unwritable": [
            .zhHans: "Application Support 不可写，设置可能无法保存。", .en: "Application Support is not writable. Settings may not save.", .ja: "Application Support に書き込めません。設定を保存できない可能性があります。", .ko: "Application Support에 쓸 수 없습니다. 설정을 저장하지 못할 수 있습니다.",
            .ru: "Application Support недоступен для записи. Настройки могут не сохраниться.", .ar: "Application Support غير قابل للكتابة. قد لا تُحفظ الإعدادات.", .fr: "Application Support n’est pas accessible en écriture. Les réglages peuvent ne pas se sauver.", .de: "Application Support ist nicht beschreibbar. Einstellungen speichern möglicherweise nicht.",
            .es: "Application Support no es escribible. Puede que no se guarden los ajustes.", .pt: "Application Support não é gravável. As definições podem não gravar.",
        ],
        "compat.logs.ok": [
            .zhHans: "日志目录可写。", .en: "The log directory is writable.", .ja: "ログディレクトリに書き込めます。", .ko: "로그 디렉터리에 쓸 수 있습니다.",
            .ru: "Папка журналов доступна для записи.", .ar: "مجلد السجلات قابل للكتابة.", .fr: "Le dossier des journaux est accessible en écriture.", .de: "Der Protokollordner ist beschreibbar.",
            .es: "La carpeta de registros es escribible.", .pt: "A pasta de registos é gravável.",
        ],
        "compat.logs.unwritable": [
            .zhHans: "日志目录不可写。", .en: "The log directory is not writable.", .ja: "ログディレクトリに書き込めません。", .ko: "로그 디렉터리에 쓸 수 없습니다.",
            .ru: "Папка журналов недоступна для записи.", .ar: "مجلد السجلات غير قابل للكتابة.", .fr: "Le dossier des journaux n’est pas accessible en écriture.", .de: "Der Protokollordner ist nicht beschreibbar.",
            .es: "La carpeta de registros no es escribible.", .pt: "A pasta de registos não é gravável.",
        ],
        "compat.keychain.available": [
            .zhHans: "普通钥匙串可访问。", .en: "The ordinary Keychain is reachable.", .ja: "通常のキーチェーンに到達できます。", .ko: "일반 키체인에 접근할 수 있습니다.",
            .ru: "Обычная связка ключей доступна.", .ar: "سلسلة المفاتيح العادية قابلة للوصول.", .fr: "Le trousseau ordinaire est accessible.", .de: "Die normale Schlüsselkette ist erreichbar.",
            .es: "El llavero ordinario es accesible.", .pt: "O Porta-chaves normal está acessível.",
        ],
        "compat.keychain.unavailable": [
            .zhHans: "普通钥匙串不可用。", .en: "The ordinary Keychain is unavailable.", .ja: "通常のキーチェーンを利用できません。", .ko: "일반 키체인을 사용할 수 없습니다.",
            .ru: "Обычная связка ключей недоступна.", .ar: "سلسلة المفاتيح العادية غير متاحة.", .fr: "Le trousseau ordinaire est indisponible.", .de: "Die normale Schlüsselkette ist nicht verfügbar.",
            .es: "El llavero ordinario no está disponible.", .pt: "O Porta-chaves normal não está disponível.",
        ],
        "compat.notifications.authorized": [
            .zhHans: "通知已授权。", .en: "Notifications are authorized.", .ja: "通知は許可されています。", .ko: "알림이 허용되어 있습니다.",
            .ru: "Уведомления разрешены.", .ar: "الإشعارات مُصرَّح بها.", .fr: "Les notifications sont autorisées.", .de: "Mitteilungen sind freigegeben.",
            .es: "Las notificaciones están autorizadas.", .pt: "As notificações estão autorizadas.",
        ],
        "compat.notifications.notDetermined": [
            .zhHans: "通知尚未决定。这不是渠道失败。", .en: "Notification permission is not decided yet. This is not a provider failure.", .ja: "通知の許可は未決定です。これはチャネル故障ではありません。", .ko: "알림 권한이 아직 결정되지 않았습니다. 채널 실패가 아닙니다.",
            .ru: "Разрешение уведомлений ещё не выбрано. Это не сбой канала.", .ar: "إذن الإشعارات لم يُحدَّد بعد. هذا ليس فشل مزوّد.", .fr: "L’autorisation des notifications n’est pas encore choisie. Ce n’est pas un échec de canal.", .de: "Die Mitteilungsfreigabe ist noch offen. Das ist kein Kanalfehler.",
            .es: "El permiso de notificaciones aún no se ha decidido. No es un fallo del proveedor.", .pt: "A autorização de notificações ainda não foi decidida. Não é falha do provedor.",
        ],
        "compat.notifications.denied": [
            .zhHans: "通知已被拒绝。可在系统设置中打开，这不是渠道失败。", .en: "Notifications were denied. You can enable them in System Settings. This is not a provider failure.", .ja: "通知は拒否されています。システム設定で開けます。チャネル故障ではありません。", .ko: "알림이 거부되었습니다. 시스템 설정에서 켤 수 있으며 채널 실패가 아닙니다.",
            .ru: "Уведомления отклонены. Их можно включить в системных настройках. Это не сбой канала.", .ar: "رُفضت الإشعارات. يمكن تفعيلها من إعدادات النظام. هذا ليس فشل مزوّد.", .fr: "Les notifications sont refusées. Activez-les dans Réglages Système. Ce n’est pas un échec de canal.", .de: "Mitteilungen wurden abgelehnt. In den Systemeinstellungen aktivierbar. Kein Kanalfehler.",
            .es: "Las notificaciones están denegadas. Actívalas en Ajustes del Sistema. No es un fallo del proveedor.", .pt: "As notificações foram recusadas. Ative-as nas Definições do Sistema. Não é falha do provedor.",
        ],
        "compat.notifications.restricted": [
            .zhHans: "通知受限。这不是渠道失败。", .en: "Notifications are restricted. This is not a provider failure.", .ja: "通知が制限されています。チャネル故障ではありません。", .ko: "알림이 제한되어 있습니다. 채널 실패가 아닙니다.",
            .ru: "Уведомления ограничены. Это не сбой канала.", .ar: "الإشعارات مقيّدة. هذا ليس فشل مزوّد.", .fr: "Les notifications sont restreintes. Ce n’est pas un échec de canal.", .de: "Mitteilungen sind eingeschränkt. Das ist kein Kanalfehler.",
            .es: "Las notificaciones están restringidas. No es un fallo del proveedor.", .pt: "As notificações estão restritas. Não é falha do provedor.",
        ],
        "compat.notifications.unknown": [
            .zhHans: "通知状态未知。这不是渠道失败。", .en: "Notification status is unknown. This is not a provider failure.", .ja: "通知状態は不明です。チャネル故障ではありません。", .ko: "알림 상태를 알 수 없습니다. 채널 실패가 아닙니다.",
            .ru: "Состояние уведомлений неизвестно. Это не сбой канала.", .ar: "حالة الإشعارات غير معروفة. هذا ليس فشل مزوّد.", .fr: "L’état des notifications est inconnu. Ce n’est pas un échec de canal.", .de: "Der Mitteilungsstatus ist unbekannt. Das ist kein Kanalfehler.",
            .es: "El estado de las notificaciones es desconocido. No es un fallo del proveedor.", .pt: "O estado das notificações é desconhecido. Não é falha do provedor.",
        ],
        "compat.settings.ok": [
            .zhHans: "设置文件可读。", .en: "The settings file is readable.", .ja: "設定ファイルを読めます。", .ko: "설정 파일을 읽을 수 있습니다.",
            .ru: "Файл настроек читается.", .ar: "ملف الإعدادات قابل للقراءة.", .fr: "Le fichier des réglages est lisible.", .de: "Die Einstellungsdatei ist lesbar.",
            .es: "El archivo de ajustes es legible.", .pt: "O ficheiro de definições é legível.",
        ],
        "compat.settings.missing": [
            .zhHans: "尚未找到设置文件（新安装或尚未保存）。", .en: "No settings file yet (new install or nothing saved).", .ja: "設定ファイルはまだありません（新規または未保存）。", .ko: "설정 파일이 아직 없습니다(새 설치 또는 미저장).",
            .ru: "Файла настроек пока нет (новая установка или ничего не сохранено).", .ar: "لا يوجد ملف إعدادات بعد (تثبيت جديد أو لم يُحفظ شيء).", .fr: "Pas encore de fichier de réglages (nouvelle install ou rien d’enregistré).", .de: "Noch keine Einstellungsdatei (Neuinstallation oder nichts gespeichert).",
            .es: "Aún no hay archivo de ajustes (instalación nueva o nada guardado).", .pt: "Ainda não há ficheiro de definições (instalação nova ou nada gravado).",
        ],
        "compat.settings.corrupt": [
            .zhHans: "设置文件已损坏。现有账号不会被当成空配置。", .en: "The settings file is damaged. Existing accounts are not treated as an empty setup.", .ja: "設定ファイルが壊れています。既存アカウントを空の設定としては扱いません。", .ko: "설정 파일이 손상되었습니다. 기존 계정을 빈 설정으로 취급하지 않습니다.",
            .ru: "Файл настроек повреждён. Существующие аккаунты не считаются пустой конфигурацией.", .ar: "ملف الإعدادات تالف. لن تُعامل الحسابات الحالية كإعداد فارغ.", .fr: "Le fichier des réglages est endommagé. Les comptes existants ne sont pas traités comme une config vide.", .de: "Die Einstellungsdatei ist beschädigt. Vorhandene Konten gelten nicht als leere Konfiguration.",
            .es: "El archivo de ajustes está dañado. Las cuentas existentes no se tratan como un setup vacío.", .pt: "O ficheiro de definições está danificado. As contas existentes não são tratadas como configuração vazia.",
        ],
        "compat.settings.unreadable": [
            .zhHans: "设置文件无法读取。", .en: "The settings file could not be read.", .ja: "設定ファイルを読めません。", .ko: "설정 파일을 읽을 수 없습니다.",
            .ru: "Не удалось прочитать файл настроек.", .ar: "تعذّرت قراءة ملف الإعدادات.", .fr: "Impossible de lire le fichier des réglages.", .de: "Die Einstellungsdatei konnte nicht gelesen werden.",
            .es: "No se pudo leer el archivo de ajustes.", .pt: "Não foi possível ler o ficheiro de definições.",
        ],
        "compat.usage.ok": [
            .zhHans: "用量历史可读。", .en: "Usage history is readable.", .ja: "使用履歴を読めます。", .ko: "사용 기록을 읽을 수 있습니다.",
            .ru: "История расхода читается.", .ar: "سجل الاستخدام قابل للقراءة.", .fr: "L’historique d’utilisation est lisible.", .de: "Der Nutzungsverlauf ist lesbar.",
            .es: "El historial de uso es legible.", .pt: "O histórico de uso é legível.",
        ],
        "compat.usage.missing": [
            .zhHans: "还没有用量历史文件。新安装时这是正常的。", .en: "No usage-history file yet. That is normal on a new install.", .ja: "使用履歴ファイルはまだありません。新規インストールでは正常です。", .ko: "사용 기록 파일이 아직 없습니다. 새 설치에서는 정상입니다.",
            .ru: "Файла истории расхода пока нет. Для новой установки это нормально.", .ar: "لا يوجد ملف سجل استخدام بعد. هذا طبيعي في تثبيت جديد.", .fr: "Pas encore de fichier d’historique. C’est normal pour une nouvelle install.", .de: "Noch keine Nutzungsverlaufsdatei. Bei einer Neuinstallation ist das normal.",
            .es: "Aún no hay historial de uso. Es normal en una instalación nueva.", .pt: "Ainda não há ficheiro de histórico. É normal numa instalação nova.",
        ],
        "compat.usage.corrupt": [
            .zhHans: "用量历史无法解析。余额查询不受影响。", .en: "Usage history could not be parsed. Balance queries are unaffected.", .ja: "使用履歴を解析できません。残高照会には影響しません。", .ko: "사용 기록을 해석할 수 없습니다. 잔액 조회는 영향을 받지 않습니다.",
            .ru: "Не удалось разобрать историю расхода. Запросы баланса не затронуты.", .ar: "تعذّر تحليل سجل الاستخدام. استعلامات الرصيد غير متأثرة.", .fr: "Impossible d’analyser l’historique. Les soldes ne sont pas affectés.", .de: "Der Nutzungsverlauf konnte nicht gelesen werden. Saldos bleiben unberührt.",
            .es: "No se pudo analizar el historial. Las consultas de saldo no se ven afectadas.", .pt: "Não foi possível analisar o histórico. As consultas de saldo não são afetadas.",
        ],
        "compat.usage.unreadable": [
            .zhHans: "用量历史无法读取。", .en: "Usage history could not be read.", .ja: "使用履歴を読めません。", .ko: "사용 기록을 읽을 수 없습니다.",
            .ru: "Не удалось прочитать историю расхода.", .ar: "تعذّرت قراءة سجل الاستخدام.", .fr: "Impossible de lire l’historique d’utilisation.", .de: "Der Nutzungsverlauf konnte nicht gelesen werden.",
            .es: "No se pudo leer el historial de uso.", .pt: "Não foi possível ler o histórico de uso.",
        ],
        "compat.schema.ok": [
            .zhHans: "当前设置 schema 可用。", .en: "The current settings schema is supported.", .ja: "現在の設定スキーマは利用できます。", .ko: "현재 설정 스키마를 사용할 수 있습니다.",
            .ru: "Текущая схема настроек поддерживается.", .ar: "مخطط الإعدادات الحالي مدعوم.", .fr: "Le schéma de réglages actuel est pris en charge.", .de: "Das aktuelle Einstellungsschema wird unterstützt.",
            .es: "El esquema de ajustes actual es compatible.", .pt: "O esquema de definições atual é suportado.",
        ],
        "compat.schema.legacy": [
            .zhHans: "检测到旧版设置，将按当前 schema 读取。", .en: "A legacy settings file was found and will be read with the current schema.", .ja: "旧設定を検出し、現行スキーマで読みます。", .ko: "이전 설정 파일을 찾았으며 현재 스키마로 읽습니다.",
            .ru: "Найден старый файл настроек; он будет прочитан текущей схемой.", .ar: "وُجد ملف إعدادات قديم وسيُقرأ بالمخطط الحالي.", .fr: "Un ancien fichier de réglages a été trouvé et sera lu avec le schéma actuel.", .de: "Eine ältere Einstellungsdatei wurde gefunden und mit dem aktuellen Schema gelesen.",
            .es: "Hay un archivo de ajustes antiguo; se leerá con el esquema actual.", .pt: "Foi encontrado um ficheiro antigo; será lido com o esquema atual.",
        ],
        "compat.schema.unsupported": [
            .zhHans: "设置 schema 版本不受支持。", .en: "This settings schema version is not supported.", .ja: "この設定スキーマ版は未対応です。", .ko: "이 설정 스키마 버전은 지원되지 않습니다.",
            .ru: "Эта версия схемы настроек не поддерживается.", .ar: "إصدار مخطط الإعدادات هذا غير مدعوم.", .fr: "Cette version de schéma n’est pas prise en charge.", .de: "Diese Schema-Version wird nicht unterstützt.",
            .es: "Esta versión de esquema no es compatible.", .pt: "Esta versão de esquema não é suportada.",
        ],
        "compat.schema.missing": [
            .zhHans: "还没有可检查的设置 schema。", .en: "There is no settings schema to inspect yet.", .ja: "検査できる設定スキーマはまだありません。", .ko: "확인할 설정 스키마가 아직 없습니다.",
            .ru: "Пока нет схемы настроек для проверки.", .ar: "لا يوجد مخطط إعدادات للفحص بعد.", .fr: "Il n’y a pas encore de schéma à inspecter.", .de: "Es gibt noch kein Einstellungsschema zum Prüfen.",
            .es: "Aún no hay un esquema de ajustes que revisar.", .pt: "Ainda não há um esquema de definições para inspecionar.",
        ],
        "compat.schema.unreadable": [
            .zhHans: "无法从设置文件判断 schema。", .en: "The settings schema could not be determined.", .ja: "設定ファイルからスキーマを判断できません。", .ko: "설정 파일에서 스키마를 판단할 수 없습니다.",
            .ru: "Не удалось определить схему настроек.", .ar: "تعذّر تحديد مخطط الإعدادات.", .fr: "Impossible de déterminer le schéma des réglages.", .de: "Das Einstellungsschema konnte nicht bestimmt werden.",
            .es: "No se pudo determinar el esquema de ajustes.", .pt: "Não foi possível determinar o esquema de definições.",
        ],
        "diagnostics.facts.title": [
            .zhHans: "渠道 / 用量 / 刷新", .en: "Providers / usage / refresh", .ja: "チャネル / 使用量 / 更新", .ko: "채널 / 사용량 / 새로고침",
            .ru: "Каналы / расход / обновление", .ar: "المزوّدون / الاستخدام / التحديث", .fr: "Canaux / usage / actualisation", .de: "Kanäle / Nutzung / Aktualisierung",
            .es: "Proveedores / uso / actualización", .pt: "Provedores / uso / atualização",
        ],
        "diagnostics.title": [
            .zhHans: "诊断中心", .en: "Diagnostics", .ja: "診断", .ko: "진단",
            .ru: "Диагностика", .ar: "التشخيص", .fr: "Diagnostic", .de: "Diagnose",
            .es: "Diagnóstico", .pt: "Diagnóstico",
        ],
        "diagnostics.subtitle": [
            .zhHans: "本机检查，不含密钥或渠道原始响应。", .en: "Local checks only. No secrets or raw provider responses.", .ja: "ローカル検査のみ。秘密情報や生の応答は含みません。", .ko: "로컬 검사만 합니다. 비밀 값이나 원본 응답은 없습니다.",
            .ru: "Только локальные проверки. Без секретов и сырых ответов.", .ar: "فحوصات محلية فقط. بلا أسرار أو استجابات خام.", .fr: "Contrôles locaux uniquement. Pas de secrets ni de réponses brutes.", .de: "Nur lokale Prüfungen. Keine Geheimnisse oder Rohantworten.",
            .es: "Solo comprobaciones locales. Sin secretos ni respuestas crudas.", .pt: "Apenas verificações locais. Sem segredos nem respostas em bruto.",
        ],
        "diagnostics.loading": [
            .zhHans: "正在收集本机诊断…", .en: "Collecting local diagnostics…", .ja: "ローカル診断を収集中…", .ko: "로컬 진단을 수집하는 중…",
            .ru: "Сбор локальной диагностики…", .ar: "جارٍ جمع التشخيص المحلي…", .fr: "Collecte du diagnostic local…", .de: "Lokale Diagnose wird erfasst…",
            .es: "Recogiendo diagnóstico local…", .pt: "A recolher diagnóstico local…",
        ],
        "diagnostics.recheck": [
            .zhHans: "重新检查", .en: "Recheck", .ja: "再チェック", .ko: "다시 확인",
            .ru: "Проверить снова", .ar: "إعادة الفحص", .fr: "Revérifier", .de: "Erneut prüfen",
            .es: "Volver a comprobar", .pt: "Verificar de novo",
        ],
        "diagnostics.copy": [
            .zhHans: "复制摘要", .en: "Copy summary", .ja: "要約をコピー", .ko: "요약 복사",
            .ru: "Копировать сводку", .ar: "نسخ الملخص", .fr: "Copier le résumé", .de: "Kurzfassung kopieren",
            .es: "Copiar resumen", .pt: "Copiar resumo",
        ],
        "diagnostics.copied": [
            .zhHans: "诊断摘要已复制", .en: "Diagnostics summary copied", .ja: "診断要約をコピーしました", .ko: "진단 요약을 복사했습니다",
            .ru: "Сводка диагностики скопирована", .ar: "تم نسخ ملخص التشخيص", .fr: "Résumé du diagnostic copié", .de: "Diagnose-Kurzfassung kopiert",
            .es: "Resumen de diagnóstico copiado", .pt: "Resumo de diagnóstico copiado",
        ],
        "diagnostics.export": [
            .zhHans: "导出诊断", .en: "Export diagnostics", .ja: "診断を書き出す", .ko: "진단 내보내기",
            .ru: "Экспорт диагностики", .ar: "تصدير التشخيص", .fr: "Exporter le diagnostic", .de: "Diagnose exportieren",
            .es: "Exportar diagnóstico", .pt: "Exportar diagnóstico",
        ],
        "diagnostics.open_settings": [
            .zhHans: "打开设置", .en: "Open Settings", .ja: "設定を開く", .ko: "설정 열기",
            .ru: "Открыть настройки", .ar: "فتح الإعدادات", .fr: "Ouvrir les réglages", .de: "Einstellungen öffnen",
            .es: "Abrir ajustes", .pt: "Abrir ajustes",
        ],
        "diagnostics.open_logs": [
            .zhHans: "打开日志目录", .en: "Open log folder", .ja: "ログフォルダを開く", .ko: "로그 폴더 열기",
            .ru: "Открыть папку журналов", .ar: "فتح مجلد السجلات", .fr: "Ouvrir le dossier des journaux", .de: "Protokollordner öffnen",
            .es: "Abrir carpeta de registros", .pt: "Abrir pasta de registos",
        ],
        "diagnostics.open_help": [
            .zhHans: "打开帮助", .en: "Open help", .ja: "ヘルプを開く", .ko: "도움말 열기",
            .ru: "Открыть справку", .ar: "فتح المساعدة", .fr: "Ouvrir l’aide", .de: "Hilfe öffnen",
            .es: "Abrir ayuda", .pt: "Abrir ajuda",
        ],
        "diagnostics.banner.action": [
            .zhHans: "查看诊断", .en: "Diagnostics", .ja: "診断を見る", .ko: "진단 보기",
            .ru: "Диагностика", .ar: "التشخيص", .fr: "Diagnostic", .de: "Diagnose",
            .es: "Diagnóstico", .pt: "Diagnóstico",
        ],
        "diagnostics.export.title": [
            .zhHans: "导出本机诊断包", .en: "Export local diagnostics", .ja: "ローカル診断を書き出す", .ko: "로컬 진단 내보내기",
            .ru: "Экспорт локальной диагностики", .ar: "تصدير التشخيص المحلي", .fr: "Exporter le diagnostic local", .de: "Lokale Diagnose exportieren",
            .es: "Exportar diagnóstico local", .pt: "Exportar diagnóstico local",
        ],
        "diagnostics.export.excluded_intro": [
            .zhHans: "导出前请确认：以下字段不会写入诊断包。", .en: "Before export: these fields are excluded from the package.", .ja: "書き出し前：次の項目は診断パックに含まれません。", .ko: "내보내기 전: 아래 항목은 패키지에 포함되지 않습니다.",
            .ru: "Перед экспортом: эти поля не попадут в пакет.", .ar: "قبل التصدير: تُستبعد هذه الحقول من الحزمة.", .fr: "Avant export : ces champs sont exclus du paquet.", .de: "Vor dem Export: Diese Felder sind ausgeschlossen.",
            .es: "Antes de exportar: estos campos no van en el paquete.", .pt: "Antes de exportar: estes campos ficam de fora.",
        ],
        "diagnostics.export.confirm": [
            .zhHans: "仍要导出", .en: "Export anyway", .ja: "書き出す", .ko: "내보내기",
            .ru: "Экспортировать", .ar: "تصدير", .fr: "Exporter", .de: "Exportieren",
            .es: "Exportar", .pt: "Exportar",
        ],
        "diagnostics.export.cancel": [
            .zhHans: "取消", .en: "Cancel", .ja: "キャンセル", .ko: "취소",
            .ru: "Отмена", .ar: "إلغاء", .fr: "Annuler", .de: "Abbrechen",
            .es: "Cancelar", .pt: "Cancelar",
        ],
        "diagnostics.export.success": [
            .zhHans: "诊断包已导出", .en: "Diagnostics package exported", .ja: "診断パックを書き出しました", .ko: "진단 패키지를 내보냈습니다",
            .ru: "Пакет диагностики экспортирован", .ar: "تم تصدير حزمة التشخيص", .fr: "Paquet de diagnostic exporté", .de: "Diagnosepaket exportiert",
            .es: "Paquete de diagnóstico exportado", .pt: "Pacote de diagnóstico exportado",
        ],
        "diagnostics.export.failed": [
            .zhHans: "诊断包导出失败", .en: "Diagnostics export failed", .ja: "診断の書き出しに失敗", .ko: "진단 내보내기 실패",
            .ru: "Не удалось экспортировать диагностику", .ar: "فشل تصدير التشخيص", .fr: "Échec de l’export du diagnostic", .de: "Diagnose-Export fehlgeschlagen",
            .es: "Error al exportar el diagnóstico", .pt: "Falha ao exportar o diagnóstico",
        ],
        "settings.diagnostics": [
            .zhHans: "诊断中心", .en: "Diagnostics", .ja: "診断", .ko: "진단",
            .ru: "Диагностика", .ar: "التشخيص", .fr: "Diagnostic", .de: "Diagnose",
            .es: "Diagnóstico", .pt: "Diagnóstico",
        ],
        "settings.diagnostics_sub": [
            .zhHans: "查看本机问题并导出不含密钥的诊断包", .en: "Inspect this Mac and export a secret-free package", .ja: "この Mac を確認し、秘密情報なしの診断を書き出す", .ko: "이 Mac을 확인하고 비밀 없는 패키지를 내보냅니다",
            .ru: "Проверить этот Mac и экспортировать пакет без секретов", .ar: "افحص هذا الـ Mac وصدّر حزمة بلا أسرار", .fr: "Inspecter ce Mac et exporter un paquet sans secrets", .de: "Diesen Mac prüfen und ein paket ohne Geheimnisse exportieren",
            .es: "Revisar este Mac y exportar un paquete sin secretos", .pt: "Inspecionar este Mac e exportar um pacote sem segredos",
        ],
        "diagnostics.status.ok": [
            .zhHans: "正常", .en: "OK", .ja: "正常", .ko: "정상",
            .ru: "ОК", .ar: "حسن", .fr: "OK", .de: "OK",
            .es: "OK", .pt: "OK",
        ],
        "diagnostics.status.warning": [
            .zhHans: "注意", .en: "Warning", .ja: "注意", .ko: "주의",
            .ru: "Внимание", .ar: "تحذير", .fr: "Attention", .de: "Hinweis",
            .es: "Aviso", .pt: "Aviso",
        ],
        "diagnostics.status.failed": [
            .zhHans: "失败", .en: "Failed", .ja: "失敗", .ko: "실패",
            .ru: "Ошибка", .ar: "فشل", .fr: "Échec", .de: "Fehler",
            .es: "Error", .pt: "Falha",
        ],
        "diagnostics.status.unknown": [
            .zhHans: "未知", .en: "Unknown", .ja: "不明", .ko: "알 수 없음",
            .ru: "Неизвестно", .ar: "غير معروف", .fr: "Inconnu", .de: "Unbekannt",
            .es: "Desconocido", .pt: "Desconhecido",
        ],
        "diagnostics.check.appVersion": [
            .zhHans: "应用版本", .en: "App version", .ja: "アプリ版", .ko: "앱 버전",
            .ru: "Версия приложения", .ar: "إصدار التطبيق", .fr: "Version de l’app", .de: "App-Version",
            .es: "Versión de la app", .pt: "Versão da app",
        ],
        "diagnostics.check.macos": [
            .zhHans: "macOS 版本", .en: "macOS version", .ja: "macOS バージョン", .ko: "macOS 버전",
            .ru: "Версия macOS", .ar: "إصدار macOS", .fr: "Version de macOS", .de: "macOS-Version",
            .es: "Versión de macOS", .pt: "Versão do macOS",
        ],
        "diagnostics.check.architecture": [
            .zhHans: "处理器架构", .en: "Architecture", .ja: "アーキテクチャ", .ko: "아키텍처",
            .ru: "Архитектура", .ar: "المعمارية", .fr: "Architecture", .de: "Architektur",
            .es: "Arquitectura", .pt: "Arquitetura",
        ],
        "diagnostics.check.launchMode": [
            .zhHans: "运行方式", .en: "Launch mode", .ja: "起動方式", .ko: "실행 방식",
            .ru: "Режим запуска", .ar: "وضع التشغيل", .fr: "Mode de lancement", .de: "Startmodus",
            .es: "Modo de arranque", .pt: "Modo de arranque",
        ],
        "diagnostics.check.schema": [
            .zhHans: "设置 schema", .en: "Settings schema", .ja: "設定スキーマ", .ko: "설정 스키마",
            .ru: "Схема настроек", .ar: "مخطط الإعدادات", .fr: "Schéma des réglages", .de: "Einstellungsschema",
            .es: "Esquema de ajustes", .pt: "Esquema de definições",
        ],
        "diagnostics.check.applicationSupport": [
            .zhHans: "应用支持目录", .en: "Application Support", .ja: "Application Support", .ko: "Application Support",
            .ru: "Application Support", .ar: "Application Support", .fr: "Application Support", .de: "Application Support",
            .es: "Application Support", .pt: "Application Support",
        ],
        "diagnostics.check.logs": [
            .zhHans: "日志目录", .en: "Log directory", .ja: "ログディレクトリ", .ko: "로그 디렉터리",
            .ru: "Папка журналов", .ar: "مجلد السجلات", .fr: "Dossier des journaux", .de: "Protokollordner",
            .es: "Carpeta de registros", .pt: "Pasta de registos",
        ],
        "diagnostics.check.temporary": [
            .zhHans: "临时目录", .en: "Temporary directory", .ja: "一時ディレクトリ", .ko: "임시 디렉터리",
            .ru: "Временная папка", .ar: "المجلد المؤقت", .fr: "Dossier temporaire", .de: "Temporärer Ordner",
            .es: "Carpeta temporal", .pt: "Pasta temporária",
        ],
        "diagnostics.check.settings": [
            .zhHans: "设置文件", .en: "Settings file", .ja: "設定ファイル", .ko: "설정 파일",
            .ru: "Файл настроек", .ar: "ملف الإعدادات", .fr: "Fichier des réglages", .de: "Einstellungsdatei",
            .es: "Archivo de ajustes", .pt: "Ficheiro de definições",
        ],
        "diagnostics.check.usageHistory": [
            .zhHans: "用量历史", .en: "Usage history", .ja: "使用履歴", .ko: "사용 기록",
            .ru: "История расхода", .ar: "سجل الاستخدام", .fr: "Historique d’utilisation", .de: "Nutzungsverlauf",
            .es: "Historial de uso", .pt: "Histórico de uso",
        ],
        "diagnostics.check.migration": [
            .zhHans: "最近迁移", .en: "Latest migration", .ja: "直近の移行", .ko: "최근 마이그레이션",
            .ru: "Последняя миграция", .ar: "آخر ترحيل", .fr: "Dernière migration", .de: "Letzte Migration",
            .es: "Última migración", .pt: "Última migração",
        ],
        "diagnostics.check.backup": [
            .zhHans: "最近备份", .en: "Latest backup", .ja: "直近のバックアップ", .ko: "최근 백업",
            .ru: "Последняя резервная копия", .ar: "آخر نسخة احتياطية", .fr: "Dernière sauvegarde", .de: "Letztes Backup",
            .es: "Última copia", .pt: "Última cópia",
        ],
        "diagnostics.check.restore": [
            .zhHans: "最近恢复", .en: "Latest restore", .ja: "直近の復元", .ko: "최근 복원",
            .ru: "Последнее восстановление", .ar: "آخر استعادة", .fr: "Dernière restauration", .de: "Letzte Wiederherstellung",
            .es: "Última restauración", .pt: "Última restauro",
        ],
        "diagnostics.check.keychain": [
            .zhHans: "普通钥匙串", .en: "Ordinary Keychain", .ja: "通常のキーチェーン", .ko: "일반 키체인",
            .ru: "Обычная связка ключей", .ar: "سلسلة المفاتيح العادية", .fr: "Trousseau ordinaire", .de: "Normale Schlüsselkette",
            .es: "Llavero ordinario", .pt: "Porta-chaves normal",
        ],
        "diagnostics.check.notifications": [
            .zhHans: "通知授权", .en: "Notification authorization", .ja: "通知の許可", .ko: "알림 권한",
            .ru: "Разрешение уведомлений", .ar: "تفويض الإشعارات", .fr: "Autorisation des notifications", .de: "Mitteilungsfreigabe",
            .es: "Autorización de notificaciones", .pt: "Autorização de notificações",
        ],
        "diagnostics.check.refresh": [
            .zhHans: "刷新状态", .en: "Refresh status", .ja: "更新状態", .ko: "새로고침 상태",
            .ru: "Состояние обновления", .ar: "حالة التحديث", .fr: "État d’actualisation", .de: "Aktualisierungsstatus",
            .es: "Estado de actualización", .pt: "Estado de atualização",
        ],
        "diagnostics.check.providers": [
            .zhHans: "渠道配置", .en: "Provider configuration", .ja: "チャネル設定", .ko: "채널 구성",
            .ru: "Конфигурация каналов", .ar: "تهيئة المزوّد", .fr: "Configuration des canaux", .de: "Kanal-Konfiguration",
            .es: "Configuración de proveedores", .pt: "Configuração de provedores",
        ],
        "diagnostics.check.usage": [
            .zhHans: "用量统计", .en: "Usage statistics", .ja: "使用量", .ko: "사용량 통계",
            .ru: "Статистика расхода", .ar: "إحصاءات الاستخدام", .fr: "Statistiques d’utilisation", .de: "Nutzungsstatistik",
            .es: "Estadísticas de uso", .pt: "Estatísticas de uso",
        ],
        "diagnostics.detail.appVersion.ok": [
            .zhHans: "当前应用版本。", .en: "Current app version.",
        ],
        "diagnostics.detail.macos.ok": [
            .zhHans: "当前系统版本。", .en: "Current macOS version.",
        ],
        "diagnostics.detail.architecture.appleSilicon": [
            .zhHans: "Apple 芯片。", .en: "Apple silicon.",
        ],
        "diagnostics.detail.architecture.intel": [
            .zhHans: "Intel 处理器。", .en: "Intel processor.",
        ],
        "diagnostics.detail.architecture.unknown": [
            .zhHans: "架构未知。", .en: "Unknown architecture.",
        ],
        "diagnostics.detail.launchMode.menuBar": [
            .zhHans: "菜单栏应用。", .en: "Menu bar app.",
        ],
        "diagnostics.detail.launchMode.unknown": [
            .zhHans: "运行方式未知。", .en: "Unknown launch mode.",
        ],
        "diagnostics.detail.schema.ok": [
            .zhHans: "设置 schema 可用。", .en: "Settings schema is supported.",
        ],
        "diagnostics.detail.schema.unsupported": [
            .zhHans: "设置 schema 不受支持。", .en: "Settings schema is not supported.",
        ],
        "diagnostics.detail.applicationSupport.ok": [
            .zhHans: "Application Support 可写。", .en: "Application Support is writable.",
        ],
        "diagnostics.detail.applicationSupport.unwritable": [
            .zhHans: "Application Support 不可写。", .en: "Application Support is not writable.",
        ],
        "diagnostics.detail.logs.ok": [
            .zhHans: "日志目录可写。", .en: "Log directory is writable.",
        ],
        "diagnostics.detail.logs.unwritable": [
            .zhHans: "日志目录不可写。", .en: "Log directory is not writable.",
        ],
        "diagnostics.detail.temporary.ok": [
            .zhHans: "临时目录可写。", .en: "Temporary directory is writable.",
        ],
        "diagnostics.detail.temporary.unwritable": [
            .zhHans: "临时目录不可写。", .en: "Temporary directory is not writable.",
        ],
        "diagnostics.detail.settings.ok": [
            .zhHans: "设置文件可读。", .en: "Settings file is readable.",
        ],
        "diagnostics.detail.settings.unreadable": [
            .zhHans: "设置文件不可读。", .en: "Settings file is not readable.",
        ],
        "diagnostics.detail.usageHistory.ok": [
            .zhHans: "用量历史可读。", .en: "Usage history is readable.",
        ],
        "diagnostics.detail.usageHistory.unreadable": [
            .zhHans: "用量历史不可读。", .en: "Usage history is not readable.",
        ],
        "diagnostics.detail.migration.ok": [
            .zhHans: "最近一次迁移已留下快照。", .en: "A migration snapshot is present.",
        ],
        "diagnostics.detail.migration.none": [
            .zhHans: "尚未记录迁移结果。", .en: "No migration result recorded.",
        ],
        "diagnostics.detail.migration.failed": [
            .zhHans: "最近一次迁移失败。", .en: "The latest migration failed.",
        ],
        "diagnostics.detail.migration.unknown": [
            .zhHans: "迁移结果未知。", .en: "Migration result is unknown.",
        ],
        "diagnostics.detail.backup.ok": [
            .zhHans: "最近一次写入前已有快照。", .en: "A write snapshot is present.",
        ],
        "diagnostics.detail.backup.none": [
            .zhHans: "尚未记录备份结果。", .en: "No backup result recorded.",
        ],
        "diagnostics.detail.backup.failed": [
            .zhHans: "最近一次备份失败。", .en: "The latest backup failed.",
        ],
        "diagnostics.detail.backup.unknown": [
            .zhHans: "备份结果未知。", .en: "Backup result is unknown.",
        ],
        "diagnostics.detail.restore.ok": [
            .zhHans: "最近一次恢复已记录。", .en: "A restore result is present.",
        ],
        "diagnostics.detail.restore.none": [
            .zhHans: "尚未记录恢复结果。", .en: "No restore result recorded.",
        ],
        "diagnostics.detail.restore.failed": [
            .zhHans: "最近一次恢复失败。", .en: "The latest restore failed.",
        ],
        "diagnostics.detail.restore.unknown": [
            .zhHans: "恢复结果未知。", .en: "Restore result is unknown.",
        ],
        "diagnostics.detail.keychain.available": [
            .zhHans: "普通钥匙串可用。", .en: "Ordinary Keychain is available.",
        ],
        "diagnostics.detail.keychain.unavailable": [
            .zhHans: "普通钥匙串不可用。", .en: "Ordinary Keychain is unavailable.",
        ],
        "diagnostics.detail.keychain.unknown": [
            .zhHans: "钥匙串状态未知。", .en: "Keychain status is unknown.",
        ],
        "diagnostics.detail.notifications.authorized": [
            .zhHans: "通知已授权。", .en: "Notifications are authorized.",
        ],
        "diagnostics.detail.notifications.provisional": [
            .zhHans: "通知为临时授权。", .en: "Notifications are provisionally authorized.",
        ],
        "diagnostics.detail.notifications.notDetermined": [
            .zhHans: "通知尚未决定。", .en: "Notification permission is not decided.",
        ],
        "diagnostics.detail.notifications.denied": [
            .zhHans: "通知已被拒绝。", .en: "Notifications were denied.",
        ],
        "diagnostics.detail.notifications.restricted": [
            .zhHans: "通知受限。", .en: "Notifications are restricted.",
        ],
        "diagnostics.detail.notifications.unknown": [
            .zhHans: "通知状态未知。", .en: "Notification status is unknown.",
        ],
        "diagnostics.detail.refresh.idle": [
            .zhHans: "当前未在刷新。", .en: "Refresh is idle.",
        ],
        "diagnostics.detail.refresh.running": [
            .zhHans: "正在刷新。", .en: "Refresh is running.",
        ],
        "diagnostics.detail.refresh.cancelling": [
            .zhHans: "正在取消刷新。", .en: "Refresh is cancelling.",
        ],
        "diagnostics.detail.refresh.succeeded": [
            .zhHans: "最近一次刷新成功。", .en: "Last refresh succeeded.",
        ],
        "diagnostics.detail.refresh.partiallyFailed": [
            .zhHans: "最近一次刷新部分失败。", .en: "Last refresh partially failed.",
        ],
        "diagnostics.detail.refresh.failed": [
            .zhHans: "最近一次刷新失败。", .en: "Last refresh failed.",
        ],
        "diagnostics.detail.providers.ok": [
            .zhHans: "已记录渠道类型与凭据引用是否存在。", .en: "Provider types and credential-ref presence recorded.",
        ],
        "diagnostics.detail.usage.ok": [
            .zhHans: "用量历史摘要可用。", .en: "Usage history summary is available.",
        ],
        "diagnostics.detail.usage.warning": [
            .zhHans: "用量保存或读取出现问题。", .en: "Usage save or load reported a problem.",
        ],
        "settings.transfer": [
            .zhHans: "设置迁移", .en: "Transfer settings", .ja: "設定の移行", .ko: "설정 이전",
            .ru: "Перенос настроек", .ar: "نقل الإعدادات", .fr: "Transférer les réglages", .de: "Einstellungen übertragen",
            .es: "Transferir ajustes", .pt: "Transferir definições",
        ],
        "settings.transfer_sub": [
            .zhHans: "导出/导入非敏感设置，不含密码", .en: "Export/import non-secret settings", .ja: "機密情報なしで設定を移行", .ko: "비밀번호 없이 설정 이전",
            .ru: "Без паролей", .ar: "بدون كلمات مرور", .fr: "Sans mots de passe", .de: "Ohne Passwörter",
            .es: "Sin contraseñas", .pt: "Sem palavras-passe",
        ],
        "settings.transfer.title": [
            .zhHans: "设置迁移", .en: "Transfer settings", .ja: "設定の移行", .ko: "설정 이전",
            .ru: "Перенос настроек", .ar: "نقل الإعدادات", .fr: "Transférer les réglages", .de: "Einstellungen übertragen",
            .es: "Transferir ajustes", .pt: "Transferir definições",
        ],
        "settings.transfer.subtitle": [
            .zhHans: "只迁移账号类型、名称、报警与外观等非敏感配置。", .en: "Transfers providers, names, alerts, and appearance only.",
        ],
        "settings.transfer.no_secrets": [
            .zhHans: "不会导出 Keychain、密码或 Cookie。导入后必须重新填写凭据。", .en: "Keychain, passwords, and cookies are not exported. Re-enter credentials after import.",
        ],
        "settings.transfer.export": [
            .zhHans: "导出设置", .en: "Export settings", .ja: "設定を書き出す", .ko: "설정 내보내기",
            .ru: "Экспорт", .ar: "تصدير", .fr: "Exporter", .de: "Exportieren",
            .es: "Exportar", .pt: "Exportar",
        ],
        "settings.transfer.import": [
            .zhHans: "从文件导入", .en: "Import from file", .ja: "ファイルから読み込む", .ko: "파일에서 가져오기",
            .ru: "Импорт", .ar: "استيراد", .fr: "Importer", .de: "Importieren",
            .es: "Importar", .pt: "Importar",
        ],
        "settings.transfer.export_title": [
            .zhHans: "导出设置", .en: "Export settings",
        ],
        "settings.transfer.export_message": [
            .zhHans: "导出非敏感设置。文件不含密码，导入后需重新填写。", .en: "Export non-secret settings. Passwords are omitted.",
        ],
        "settings.transfer.import_title": [
            .zhHans: "导入设置", .en: "Import settings",
        ],
        "settings.transfer.import_message": [
            .zhHans: "选择设置迁移包。导入前会预览，默认不会写入。", .en: "Choose a settings file. Preview first; nothing is written yet.",
        ],
        "settings.transfer.export_ok": [
            .zhHans: "设置已导出（不含密钥）", .en: "Settings exported (no secrets)",
        ],
        "settings.transfer.export_failed": [
            .zhHans: "导出设置失败", .en: "Could not export settings",
        ],
        "settings.transfer.file_prefix": [
            .zhHans: "智余设置", .en: "smartbalance-settings",
        ],
        "settings.backup": [
            .zhHans: "本机备份与恢复", .en: "Local backup & restore", .ja: "ローカルバックアップ", .ko: "로컬 백업",
            .ru: "Локальная копия", .ar: "نسخة محلية", .fr: "Sauvegarde locale", .de: "Lokales Backup",
            .es: "Copia local", .pt: "Cópia local",
        ],
        "settings.backup_sub": [
            .zhHans: "可选用量历史；恢复前自动快照", .en: "Optional usage history; snapshot before restore",
        ],
        "settings.backup.title": [
            .zhHans: "本机备份", .en: "Local backup", .ja: "ローカルバックアップ", .ko: "로컬 백업",
            .ru: "Локальная копия", .ar: "نسخة محلية", .fr: "Sauvegarde locale", .de: "Lokales Backup",
            .es: "Copia local", .pt: "Cópia local",
        ],
        "settings.backup.subtitle": [
            .zhHans: "备份非敏感设置，可选附带聚合用量。不含日志、请求或密钥。", .en: "Backs up non-secret settings and optional usage totals. No logs, requests, or secrets.",
        ],
        "settings.backup.include_usage": [
            .zhHans: "包含聚合用量历史", .en: "Include aggregated usage history",
        ],
        "settings.backup.no_secrets": [
            .zhHans: "恢复前会先快照当前数据。失败会自动回滚。密钥不会被删除或导入。", .en: "A snapshot is taken first. Failures roll back. Keychain is never imported or deleted.",
        ],
        "settings.backup.export": [
            .zhHans: "导出本机备份", .en: "Export local backup",
        ],
        "settings.backup.restore": [
            .zhHans: "从备份恢复", .en: "Restore from backup",
        ],
        "settings.backup.open_dir": [
            .zhHans: "打开备份目录", .en: "Open backup folder",
        ],
        "settings.backup.export_title": [
            .zhHans: "导出本机备份", .en: "Export local backup",
        ],
        "settings.backup.export_message": [
            .zhHans: "导出本机恢复包。不含密码、日志或请求内容。", .en: "Export a local restore package without secrets or logs.",
        ],
        "settings.backup.restore_title": [
            .zhHans: "恢复本机备份", .en: "Restore local backup",
        ],
        "settings.backup.restore_message": [
            .zhHans: "选择本机备份或设置迁移包。先预览再确认。", .en: "Choose a local backup or settings file. Preview before confirming.",
        ],
        "settings.backup.export_ok": [
            .zhHans: "本机备份已导出", .en: "Local backup exported",
        ],
        "settings.backup.export_failed": [
            .zhHans: "导出本机备份失败", .en: "Could not export local backup",
        ],
        "settings.backup.file_prefix": [
            .zhHans: "智余本机备份", .en: "smartbalance-restore",
        ],
        "restore.preview.title": [
            .zhHans: "恢复预览", .en: "Restore preview",
        ],
        "restore.preview.accounts": [
            .zhHans: "账号数", .en: "Accounts",
        ],
        "restore.preview.providers": [
            .zhHans: "渠道", .en: "Providers",
        ],
        "restore.preview.reentry": [
            .zhHans: "需重新填写凭据", .en: "Credentials to re-enter",
        ],
        "restore.preview.reentry_none": [
            .zhHans: "无（仍不会导入密钥）", .en: "None (secrets still not imported)",
        ],
        "restore.preview.coverage": [
            .zhHans: "将覆盖", .en: "Will replace",
        ],
        "restore.preview.excluded": [
            .zhHans: "不会导入", .en: "Excluded",
        ],
        "restore.preview.usage": [
            .zhHans: "同时恢复用量历史", .en: "Also restore usage history",
        ],
        "restore.preview.confirm": [
            .zhHans: "确认恢复", .en: "Restore",
        ],
        "restore.preview.cancel": [
            .zhHans: "取消", .en: "Cancel",
        ],
        "restore.coverage.accounts": [
            .zhHans: "账号与渠道", .en: "Accounts",
        ],
        "restore.coverage.alerts": [
            .zhHans: "报警与邮件元数据", .en: "Alerts and mail metadata",
        ],
        "restore.coverage.theme": [
            .zhHans: "刷新/主题/语言", .en: "Refresh, theme, language",
        ],
        "restore.coverage.usage": [
            .zhHans: "聚合用量", .en: "Aggregated usage",
        ],
        "restore.legacy.warning": [
            .zhHans: "该文件可能包含旧版明文密钥，智余不会导入或写入其中的密钥。", .en: "This file may contain legacy plaintext secrets. Zhiyu will not import or write those secrets.",
        ],
        "restore.legacy.ack": [
            .zhHans: "我知道只会导入非敏感设置，且不会自动删除该文件", .en: "I understand only non-secret fields are imported and the file is not deleted",
        ],
        "restore.result.ok": [
            .zhHans: "恢复成功，请重新填写凭据", .en: "Restore succeeded. Re-enter credentials.",
        ],
        "restore.result.failed": [
            .zhHans: "恢复失败，已保留原数据", .en: "Restore failed. Original data was kept.",
        ],
        "restore.result.cancelled": [
            .zhHans: "已取消，未改动设置", .en: "Cancelled. Settings were not changed.",
        ],
        "restore.result.reentry": [
            .zhHans: "账号还在，但密码和密钥需要在设置里重新填写。", .en: "Accounts remain, but passwords and keys must be entered again.",
        ],
        "restore.result.open_backups": [
            .zhHans: "打开备份目录", .en: "Open backup folder",
        ],
        "restore.result.open_diagnostics": [
            .zhHans: "进入诊断中心", .en: "Open diagnostics",
        ],
        "restore.error.format": [
            .zhHans: "文件格式不匹配", .en: "File format does not match",
        ],
        "restore.error.version": [
            .zhHans: "备份版本过高，无法恢复", .en: "Backup version is too new",
        ],
        "restore.error.usage": [
            .zhHans: "用量历史损坏，未改动原数据", .en: "Usage history is corrupt. Original data was kept.",
        ],
        "restore.error.usage_write": [
            .zhHans: "用量写入失败，已回滚", .en: "Usage write failed and was rolled back",
        ],
        "restore.error.settings": [
            .zhHans: "设置写入失败，已回滚", .en: "Settings write failed and was rolled back",
        ],
        "restore.error.read": [
            .zhHans: "无法读取所选文件", .en: "Could not read the selected file",
        ],
        "restore.error.decode": [
            .zhHans: "无法解析该文件", .en: "Could not parse this file",
        ],
    ]
}
