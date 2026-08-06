import SwiftUI
import Domain

struct PlatformMailSection: View {
    @ObservedObject var model: AppModel

    @State private var mailName = ""
    @State private var mailFrom = ""
    @State private var mailSubject = ""
    @State private var mailUnit = "¥"
    @State private var mailRegex = ""
    @State private var parseTarget: PlatformMailSource?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sourcesCard
            addCard
        }
        .sheet(item: $parseTarget) { src in
            PasteMailParseSheet(source: src, model: model)
        }
    }

    private var sourcesCard: some View {
        SettingsChrome.card(title: "平台邮件源（无实时 API）") {
            Text("匹配平台「固定发件邮箱」发来的余额/报警信，解析金额后展示。")
                .font(.system(size: 11))
                .foregroundStyle(SBTheme.muted)
            if model.settings.mailSources.isEmpty {
                Text("暂无")
                    .font(.system(size: 12))
                    .foregroundStyle(SBTheme.muted)
            } else {
                ForEach(model.settings.mailSources) { src in
                    mailSourceRow(src)
                    if src.id != model.settings.mailSources.last?.id {
                        Divider().overlay(SBTheme.stroke)
                    }
                }
            }
        }
    }

    private func mailSourceRow(_ src: PlatformMailSource) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(src.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SBTheme.text)
                Text("发件人含 \(src.fromContains)")
                    .font(.system(size: 10))
                    .foregroundStyle(SBTheme.muted)
            }
            Spacer(minLength: 4)
            Button("试解析") {
                parseTarget = src
            }
            .buttonStyle(SBButtonStyle(kind: .normal))
            Toggle("", isOn: Binding(
                get: { src.enabled },
                set: { model.toggleMailSource(src.id, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            Button(role: .destructive) {
                model.removeMailSource(src.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(SBTheme.danger)
            }
            .buttonStyle(.plain)
        }
    }

    private var addCard: some View {
        SettingsChrome.card(title: "添加平台邮件源") {
            TextField("显示名称", text: $mailName)
                .textFieldStyle(.roundedBorder)
            TextField("发件人包含（必填）如 noreply@xxx.com", text: $mailFrom)
                .textFieldStyle(.roundedBorder)
            TextField("主题包含（可选）", text: $mailSubject)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("单位 ¥/$", text: $mailUnit)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                TextField("金额正则（可选，含一个捕获组）", text: $mailRegex)
                    .textFieldStyle(.roundedBorder)
            }
            Button("添加邮件源") {
                model.addMailSource(
                    displayName: mailName,
                    fromContains: mailFrom,
                    subjectContains: mailSubject,
                    unit: mailUnit,
                    regex: mailRegex
                )
                mailName = ""; mailFrom = ""; mailSubject = ""; mailRegex = ""
            }
            .buttonStyle(SBButtonStyle(kind: .accent))
            .disabled(mailFrom.isEmpty)
        }
    }
}
