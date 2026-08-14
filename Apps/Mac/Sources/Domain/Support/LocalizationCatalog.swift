import Foundation

/// Support chrome and help strings. Missing languages fall back to zh-Hans, then en.
public enum LocalizationLengthPolicy: Sendable {
    public static let panelWidth: CGFloat = 380
    public static let maxChromeWidth: CGFloat = 352
}

public enum LocalizationCatalog: Sendable {
    public static var requiredKeys: [String] { table.keys.sorted() }

    public static let titleAndButtonKeys: [String] = [
        "nav.back",
        "nav.done",
        "home.title",
        "home.settings",
        "home.usage",
        "home.open_dashboard",
        "refresh.action",
        "usage.title",
        "usage.open_settings",
        "settings.title",
        "diagnostics.title",
        "diagnostics.open_help",
        "help.title",
        "help.open",
        "help.topic.title",
        "error.retry",
        "error.help",
        "error.settings",
        "error.reenter",
        "error.logs",
        "error.export",
        "error.restore",
    ]

    public static func contains(_ key: String) -> Bool {
        table[key] != nil
    }

    public static func hasExplicitFallback(_ key: String) -> Bool {
        hasExplicitTranslation(key, language: .zhHans) || hasExplicitTranslation(key, language: .en)
    }

    public static func hasExplicitTranslation(_ key: String, language: AppLanguage) -> Bool {
        guard let value = table[key]?[language] else { return false }
        return !value.isEmpty
    }

    public static func string(_ key: String, language: AppLanguage) -> String {
        guard let row = table[key] else { return key }
        if let value = row[language], !value.isEmpty { return value }
        if let value = row[.zhHans], !value.isEmpty { return value }
        if let value = row[.en], !value.isEmpty { return value }
        return key
    }

    public static func format(_ key: String, language: AppLanguage, args: [String]) -> String {
        let template = string(key, language: language)
        guard !args.isEmpty else { return template }
        return String(format: template, arguments: args)
    }

    private typealias Row = [AppLanguage: String]

    private static func chrome(
        _ zh: String,
        _ en: String,
        ja: String,
        ko: String,
        ru: String,
        ar: String,
        fr: String,
        de: String,
        es: String,
        pt: String
    ) -> Row {
        [
            .zhHans: zh, .en: en, .ja: ja, .ko: ko, .ru: ru,
            .ar: ar, .fr: fr, .de: de, .es: es, .pt: pt,
        ]
    }

    private static func zhEn(_ zh: String, _ en: String) -> Row {
        [.zhHans: zh, .en: en]
    }

    private static let table: [String: Row] = [
        "nav.back": chrome(
            "返回", "Back",
            ja: "戻る", ko: "뒤로", ru: "Назад", ar: "رجوع",
            fr: "Retour", de: "Zurück", es: "Volver", pt: "Voltar"
        ),
        "nav.done": chrome(
            "完成", "Done",
            ja: "完了", ko: "완료", ru: "Готово", ar: "تم",
            fr: "OK", de: "Fertig", es: "Listo", pt: "Concluir"
        ),
        "home.title": chrome(
            "智余", "SmartBalance",
            ja: "智余", ko: "智余", ru: "智余", ar: "智余",
            fr: "智余", de: "智余", es: "智余", pt: "智余"
        ),
        "home.settings": chrome(
            "设置", "Settings",
            ja: "設定", ko: "설정", ru: "Настройки", ar: "الإعدادات",
            fr: "Réglages", de: "Einstellungen", es: "Ajustes", pt: "Ajustes"
        ),
        "home.usage": chrome(
            "用量", "Usage",
            ja: "使用量", ko: "사용량", ru: "Расход", ar: "الاستخدام",
            fr: "Utilisation", de: "Nutzung", es: "Uso", pt: "Uso"
        ),
        "home.open_dashboard": chrome(
            "打开后台", "Dashboard",
            ja: "コンソール", ko: "콘솔", ru: "Консоль", ar: "لوحة التحكم",
            fr: "Console", de: "Konsole", es: "Consola", pt: "Console"
        ),
        "refresh.action": chrome(
            "刷新全部", "Refresh all",
            ja: "すべて更新", ko: "모두 새로고침", ru: "Обновить всё", ar: "تحديث الكل",
            fr: "Tout actualiser", de: "Alle aktualisieren", es: "Actualizar todo", pt: "Atualizar tudo"
        ),
        "usage.title": chrome(
            "用量统计", "Usage",
            ja: "使用量", ko: "사용량 통계", ru: "Статистика расхода", ar: "إحصاءات الاستخدام",
            fr: "Statistiques d’utilisation", de: "Nutzungsstatistik", es: "Estadísticas de uso", pt: "Estatísticas de uso"
        ),
        "usage.open_settings": chrome(
            "前往设置", "Open Settings",
            ja: "設定を開く", ko: "설정 열기", ru: "Открыть настройки", ar: "فتح الإعدادات",
            fr: "Ouvrir les réglages", de: "Einstellungen öffnen", es: "Abrir ajustes", pt: "Abrir ajustes"
        ),
        "usage.day": chrome(
            "天", "Day",
            ja: "日", ko: "일", ru: "День", ar: "اليوم",
            fr: "Jour", de: "Tag", es: "Día", pt: "Dia"
        ),
        "usage.week": chrome(
            "周", "Week",
            ja: "週", ko: "주", ru: "Неделя", ar: "الأسبوع",
            fr: "Semaine", de: "Woche", es: "Semana", pt: "Semana"
        ),
        "usage.month": chrome(
            "月", "Month",
            ja: "月", ko: "월", ru: "Месяц", ar: "الشهر",
            fr: "Mois", de: "Monat", es: "Mes", pt: "Mês"
        ),
        "usage.estimated_quality": chrome(
            "余额估算", "Balance estimate",
            ja: "残高推定", ko: "잔액 추정", ru: "Оценка по балансу", ar: "تقدير من الرصيد",
            fr: "Estimation du solde", de: "Saldo-Schätzung", es: "Estimación por saldo", pt: "Estimativa pelo saldo"
        ),
        "usage.provider_quality": chrome(
            "接口统计", "Provider data",
            ja: "API 集計", ko: "API 집계", ru: "Данные сервиса", ar: "بيانات المزوّد",
            fr: "Données fournisseur", de: "Anbieterdaten", es: "Datos del proveedor", pt: "Dados do provedor"
        ),
        "usage.mixed_quality": chrome(
            "混合统计", "Mixed data",
            ja: "混合集計", ko: "혼합 집계", ru: "Смешанные данные", ar: "بيانات مختلطة",
            fr: "Données mixtes", de: "Gemischte Daten", es: "Datos mixtos", pt: "Dados mistos"
        ),
        "usage.chart.summary": zhEn("合计 %@ · %@", "%@ · %@"),
        "usage.chart.line": zhEn("%@合计 %@ · %@ 个数据点", "%@ total %@ · %@ data points"),
        "usage.chart.provider": zhEn("%@ %@ · %@", "%@ %@ · %@"),
        "settings.title": chrome(
            "设置", "Settings",
            ja: "設定", ko: "설정", ru: "Настройки", ar: "الإعدادات",
            fr: "Réglages", de: "Einstellungen", es: "Ajustes", pt: "Ajustes"
        ),
        "settings.done": chrome(
            "完成", "Done",
            ja: "完了", ko: "완료", ru: "Готово", ar: "تم",
            fr: "OK", de: "Fertig", es: "Listo", pt: "Concluir"
        ),
        "settings.help": chrome(
            "帮助中心", "Help",
            ja: "ヘルプ", ko: "도움말", ru: "Справка", ar: "المساعدة",
            fr: "Aide", de: "Hilfe", es: "Ayuda", pt: "Ajuda"
        ),
        "settings.help_sub": zhEn(
            "本机排障步骤。没有云端客服。",
            "Local troubleshooting. No remote support desk."
        ),
        "settings.transfer.title": chrome(
            "设置迁移", "Transfer settings",
            ja: "設定の移行", ko: "설정 이전", ru: "Перенос настроек", ar: "نقل الإعدادات",
            fr: "Transférer les réglages", de: "Einstellungen übertragen", es: "Transferir ajustes", pt: "Transferir definições"
        ),
        "settings.backup.title": chrome(
            "本机备份", "Local backup",
            ja: "ローカルバックアップ", ko: "로컬 백업", ru: "Локальная копия", ar: "نسخة محلية",
            fr: "Sauvegarde locale", de: "Lokales Backup", es: "Copia local", pt: "Cópia local"
        ),
        "diagnostics.title": chrome(
            "诊断中心", "Diagnostics",
            ja: "診断", ko: "진단", ru: "Диагностика", ar: "التشخيص",
            fr: "Diagnostic", de: "Diagnose", es: "Diagnóstico", pt: "Diagnóstico"
        ),
        "diagnostics.open_help": chrome(
            "打开帮助", "Open help",
            ja: "ヘルプを開く", ko: "도움말 열기", ru: "Открыть справку", ar: "فتح المساعدة",
            fr: "Ouvrir l’aide", de: "Hilfe öffnen", es: "Abrir ayuda", pt: "Abrir ajuda"
        ),
        "help.title": chrome(
            "帮助中心", "Help",
            ja: "ヘルプ", ko: "도움말", ru: "Справка", ar: "المساعدة",
            fr: "Aide", de: "Hilfe", es: "Ayuda", pt: "Ajuda"
        ),
        "help.open": chrome(
            "查看帮助", "View help",
            ja: "ヘルプ", ko: "도움말", ru: "Справка", ar: "المساعدة",
            fr: "Aide", de: "Hilfe", es: "Ayuda", pt: "Ajuda"
        ),
        "help.subtitle": zhEn(
            "这些步骤在本机完成。智余不会远程处理，也不会保证渠道每次都能查到。",
            "These steps stay on this Mac. Zhiyu cannot act remotely and cannot promise every provider query will succeed."
        ),
        "help.topic.title": chrome(
            "排障说明", "Troubleshooting",
            ja: "トラブルシュート", ko: "문제 해결", ru: "Устранение неполадок", ar: "استكشاف الأخطاء",
            fr: "Dépannage", de: "Fehlerbehebung", es: "Solución de problemas", pt: "Resolução de problemas"
        ),
        "help.topic.gettingStarted.title": zhEn("开始使用", "Get started"),
        "help.topic.gettingStarted.body1": zhEn(
            "智余把设置、用量和日志留在这台 Mac。添加渠道后可以查询余额。",
            "Settings, usage, and logs stay on this Mac. After you add a provider, you can query balances."
        ),
        "help.topic.gettingStarted.body2": zhEn(
            "查询结果取决于该渠道和本机网络。智余不能保证每次都能查到。",
            "Results depend on the provider and this Mac’s network. Zhiyu cannot promise every query will succeed."
        ),
        "help.topic.refreshFailed.title": zhEn("刷新失败", "Refresh failed"),
        "help.topic.refreshFailed.body1": zhEn(
            "刷新失败常见原因是网络、凭据过期或渠道暂时不可用。",
            "Refresh often fails because of the network, expired credentials, or a temporary provider outage."
        ),
        "help.topic.refreshFailed.body2": zhEn(
            "可以重试、到设置里重新填写凭据，或导出本机诊断。智余不会替你修复渠道。",
            "Retry, re-enter credentials in Settings, or export local diagnostics. Zhiyu cannot repair the provider for you."
        ),
        "help.topic.credentials.title": zhEn("重新填写凭据", "Re-enter credentials"),
        "help.topic.credentials.body1": zhEn(
            "密钥只保存在本机普通钥匙串。导入设置或恢复备份后需要重新填写。",
            "Secrets stay in the ordinary local Keychain. Re-enter them after importing settings or restoring a backup."
        ),
        "help.topic.credentials.body2": zhEn(
            "智余不会从别处找回 API Key、Cookie 或 SMTP 密码。",
            "Zhiyu cannot recover API keys, cookies, or SMTP passwords from anywhere else."
        ),
        "help.topic.usageHistory.title": zhEn("用量历史", "Usage history"),
        "help.topic.usageHistory.body1": zhEn(
            "用量按本机自然日、ISO 周和自然月统计，不做汇率换算。",
            "Usage uses local calendar days, ISO weeks, and calendar months. Currencies are not converted."
        ),
        "help.topic.usageHistory.body2": zhEn(
            "历史损坏时会先备份再重新记录，这不是零用量。可从本机备份恢复。",
            "A damaged history is backed up and recording restarts. That is not zero usage. Restore from a local backup if you have one."
        ),
        "help.topic.diagnostics.title": zhEn("诊断与日志", "Diagnostics and logs"),
        "help.topic.diagnostics.body1": zhEn(
            "诊断只收集本机事实，不含密钥或渠道原始响应。",
            "Diagnostics collect local facts only. Secrets and raw provider responses stay out."
        ),
        "help.topic.diagnostics.body2": zhEn(
            "诊断包保存在你选择的位置，不会上传。没有远程客服会接手处理。",
            "The package is saved where you choose and is not uploaded. There is no remote desk that will take it over."
        ),
        "help.topic.backupRestore.title": zhEn("备份与恢复", "Backup and restore"),
        "help.topic.backupRestore.body1": zhEn(
            "本机备份不含密码。恢复后需要重新填写凭据。",
            "Local backups omit passwords. Re-enter credentials after restore."
        ),
        "help.topic.backupRestore.body2": zhEn(
            "旧版备份若含明文密钥，智余不会导入这些密钥。",
            "If a legacy backup contains plaintext secrets, Zhiyu will not import those secrets."
        ),
        "help.topic.updates.title": zhEn("检查更新", "Check for updates"),
        "help.topic.updates.body1": zhEn(
            "更新需要你查看说明并确认后才会下载安装。",
            "Updates download and install only after you review the notes and confirm."
        ),
        "help.topic.updates.body2": zhEn(
            "智余不会在后台静默替换当前应用。",
            "Zhiyu will not silently replace the running app in the background."
        ),
        "help.topic.notifications.title": zhEn("通知权限", "Notifications"),
        "help.topic.notifications.body1": zhEn(
            "未授权 Mac 通知不是渠道失败。可跳过并稍后在设置里开启。",
            "Declining Mac notifications is not a provider failure. Skip and enable later in Settings."
        ),
        "help.topic.notifications.body2": zhEn(
            "只有你明确点开启时，才会向系统请求通知权限。",
            "The system prompt appears only after you explicitly choose to enable notifications."
        ),
        "help.topic.safeMode.title": zhEn("安全模式", "Safe mode"),
        "help.topic.safeMode.body1": zhEn(
            "安全模式会暂停渠道请求。请先恢复快照、导出设置或查看诊断。",
            "Safe mode pauses provider requests. Restore a snapshot, export settings, or open diagnostics first."
        ),
        "help.topic.safeMode.body2": zhEn(
            "重置不会删除钥匙串里的残留凭据，也不会自动修好损坏文件。",
            "Reset does not delete leftover Keychain items and does not repair damaged files by itself."
        ),
        "help.topic.narrowWindow.title": zhEn("窄窗口与辅助功能", "Narrow window and accessibility"),
        "help.topic.narrowWindow.body1": zhEn(
            "菜单窗口约为 380×580。标题、返回和主要按钮应保持可见。",
            "The menu window is about 380×580. Titles, Back, and primary buttons should stay visible."
        ),
        "help.topic.narrowWindow.body2": zhEn(
            "图表同时提供文字摘要。渠道和状态不只靠颜色区分。减少动态效果时动画会关闭。",
            "Charts also have a text summary. Channels and status are not color-only. Reduce Motion turns animations off."
        ),
        "error.retry": chrome(
            "重试", "Retry",
            ja: "再試行", ko: "다시 시도", ru: "Повторить", ar: "إعادة المحاولة",
            fr: "Réessayer", de: "Erneut", es: "Reintentar", pt: "Tentar de novo"
        ),
        "error.help": chrome(
            "查看帮助", "View help",
            ja: "ヘルプ", ko: "도움말", ru: "Справка", ar: "المساعدة",
            fr: "Aide", de: "Hilfe", es: "Ayuda", pt: "Ajuda"
        ),
        "error.settings": chrome(
            "打开设置", "Open Settings",
            ja: "設定を開く", ko: "설정 열기", ru: "Открыть настройки", ar: "فتح الإعدادات",
            fr: "Ouvrir les réglages", de: "Einstellungen öffnen", es: "Abrir ajustes", pt: "Abrir ajustes"
        ),
        "error.reenter": chrome(
            "重新填写凭据", "Re-enter credentials",
            ja: "資格情報を再入力", ko: "자격 증명 다시 입력", ru: "Ввести данные снова", ar: "إعادة إدخال البيانات",
            fr: "Ressaisir les identifiants", de: "Zugangsdaten erneut", es: "Volver a introducir", pt: "Reintroduzir credenciais"
        ),
        "error.logs": chrome(
            "打开日志", "Open logs",
            ja: "ログを開く", ko: "로그 열기", ru: "Открыть журнал", ar: "فتح السجلات",
            fr: "Ouvrir les journaux", de: "Protokolle öffnen", es: "Abrir registros", pt: "Abrir registos"
        ),
        "error.export": chrome(
            "导出诊断", "Export diagnostics",
            ja: "診断を書き出す", ko: "진단 내보내기", ru: "Экспорт диагностики", ar: "تصدير التشخيص",
            fr: "Exporter le diagnostic", de: "Diagnose exportieren", es: "Exportar diagnóstico", pt: "Exportar diagnóstico"
        ),
        "error.restore": chrome(
            "恢复备份", "Restore backup",
            ja: "バックアップを復元", ko: "백업 복원", ru: "Восстановить копию", ar: "استعادة النسخة",
            fr: "Restaurer la sauvegarde", de: "Backup wiederherstellen", es: "Restaurar copia", pt: "Restaurar cópia"
        ),
        "error.network.title": zhEn("网络或超时", "Network or timeout"),
        "error.network.message": zhEn(
            "可以重试或查看帮助。先不必改密钥。",
            "Retry or view help. You do not need to change credentials first."
        ),
        "error.export.failed.title": zhEn("导出失败", "Export failed"),
        "error.export.failed.message": zhEn(
            "可重试、打开设置或查看帮助。",
            "Retry, open Settings, or view help."
        ),
        "refresh.running": chrome(
            "查询中…", "Refreshing…",
            ja: "更新中…", ko: "새로고침 중…", ru: "Обновление…", ar: "جارٍ التحديث…",
            fr: "Actualisation…", de: "Aktualisieren…", es: "Actualizando…", pt: "A atualizar…"
        ),
        "error.refresh.failed.title": zhEn("刷新失败", "Refresh failed"),
        "error.refresh.failed.message": zhEn(
            "可以重试、打开设置检查账号，或查看帮助。",
            "Retry, open Settings to check accounts, or view help."
        ),
        "error.refresh.partial.title": zhEn("部分账号刷新失败", "Some accounts failed to refresh"),
        "error.refresh.partial.message": zhEn(
            "已保留成功的结果。可重试失败账号或查看帮助。",
            "Successful results were kept. Retry the failed accounts or view help."
        ),
        "error.usage.save.title": zhEn("用量保存失败", "Usage save failed"),
        "error.usage.save.message": zhEn(
            "余额显示不受影响。可重试保存、导出诊断或查看帮助。",
            "Balances are unaffected. Retry the save, export diagnostics, or view help."
        ),
        "error.usage.load.title": zhEn("无法读取用量历史", "Usage history could not be read"),
        "error.usage.load.message": zhEn(
            "这不是零用量。可恢复备份或查看帮助。",
            "This is not zero usage. Restore a backup or view help."
        ),
        "error.usage.restore.title": zhEn("用量历史需要恢复", "Usage history needs restore"),
        "error.usage.restore.message": zhEn(
            "损坏文件已备份。可恢复本机备份或查看帮助。",
            "The damaged file was backed up. Restore a local backup or view help."
        ),
        "error.credentials.title": zhEn("需要重新填写凭据", "Credentials need to be re-entered"),
        "error.credentials.message": zhEn(
            "到设置里重新填写密钥，或查看帮助。",
            "Re-enter secrets in Settings, or view help."
        ),
        "error.diagnostics.export.title": zhEn("诊断包导出失败", "Diagnostics export failed"),
        "error.diagnostics.export.message": zhEn(
            "可重试、打开日志目录或查看帮助。",
            "Retry, open the log folder, or view help."
        ),
        "error.restore.failed.title": zhEn("恢复失败", "Restore failed"),
        "error.restore.failed.message": zhEn(
            "原数据已保留。可重试、打开日志或查看帮助。",
            "Original data was kept. Retry, open logs, or view help."
        ),
        "error.update.check.title": zhEn("检查更新失败", "Update check failed"),
        "error.update.check.message": zhEn(
            "可重试或查看帮助。也可打开 GitHub 手动下载。",
            "Retry or view help. You can also open GitHub and download manually."
        ),
        "error.update.install.title": zhEn("安装更新失败", "Update install failed"),
        "error.update.install.message": zhEn(
            "当前应用未改动。可重试、打开日志或查看帮助。",
            "The running app was not changed. Retry, open logs, or view help."
        ),
        "error.settings.corrupt.title": zhEn("设置文件无法使用", "Settings file is unusable"),
        "error.settings.corrupt.message": zhEn(
            "可打开设置、恢复备份或查看帮助。现有账号不会被当成空安装。",
            "Open Settings, restore a backup, or view help. Existing accounts are not treated as a blank install."
        ),
        "error.compat.blocked.title": zhEn("环境需要处理", "Environment needs attention"),
        "error.compat.blocked.message": zhEn(
            "可打开设置查看兼容性，或查看帮助。",
            "Open Settings to review compatibility, or view help."
        ),
        "home.empty.title": zhEn("智余 · 监控 API 余额", "SmartBalance · watch API balances"),
        "home.empty.subtitle": zhEn(
            "在菜单栏查看各平台 API / Token 还剩多少。",
            "Check remaining API / token balances from the menu bar."
        ),
        "home.empty.step1": zhEn("1. 设置 → API 账号 → 添加平台", "1. Settings → API accounts → add a provider"),
        "home.empty.step2": zhEn("2. 填写 Key / Cookie / 令牌后查询余额", "2. Enter a key, cookie, or token, then refresh"),
        "home.empty.step3": zhEn("3. 偏低时可用 Mac 通知或邮件提醒", "3. Low balances can use Mac notifications or email"),
        "home.empty.step4": zhEn("4. 长按卡片可调整顺序", "4. Long-press a card to reorder"),
        "home.empty.action": zhEn("去添加账号", "Add an account"),
        "home.recent_alerts": zhEn("最近报警", "Recent alerts"),
        "home.alert.notified": zhEn("通知", "Notify"),
        "home.alert.emailed": zhEn("邮件", "Email"),
        "home.pin.on": zhEn("取消置顶", "Unpin window"),
        "home.pin.off": zhEn("置顶常驻窗口（点其他应用不关闭）", "Pin window (stays open when you click away)"),
        "home.dashboard.help": zhEn("打开当前选中账号对应平台控制台", "Open the selected account’s provider console"),
        "home.quit.help": zhEn("完全退出智余（菜单栏图标会消失）", "Quit Zhiyu (the menu bar icon disappears)"),
        "card.available": zhEn("可用", "Available"),
        "card.used": zhEn("已用", "Used"),
        "card.total": zhEn("总额", "Total"),
        "card.remaining": zhEn("剩余", "Left"),
        "card.reorder": zhEn("排序卡片", "Reorder cards"),
        "status.healthy": zhEn("充足", "OK"),
        "status.warning": zhEn("偏低", "Low"),
        "status.caution": zhEn("不足", "Low"),
        "status.critical": zhEn("危急", "Critical"),
        "status.depleted": zhEn("耗尽", "Empty"),
        "status.unknown": zhEn("查询中", "Checking"),
        "status.error": zhEn("失败", "Failed"),
        "status.setup": zhEn("待配置", "Setup"),
        "a11y.selected": zhEn("已选中", "Selected"),
        "a11y.expanded": zhEn("已展开", "Expanded"),
        "a11y.collapsed": zhEn("已折叠", "Collapsed"),
    ]
}
