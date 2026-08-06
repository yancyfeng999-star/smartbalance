import SwiftUI
import Domain

struct PlatformMailSection: View {
    @ObservedObject var model: AppModel
    var embedded: Bool = false

    @State private var mailName = ""
    @State private var mailFrom = ""
    @State private var mailSubject = ""
    @State private var mailUnit = "¥"
    @State private var mailRegex = ""
    @State private var parseTarget: PlatformMailSource?

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                SettingsChrome.card(title: "平台邮件源") { content }
            }
        }
        .sheet(item: $parseTarget) { src in
            PasteMailParseSheet(source: src, model: model)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("匹配固定发件邮箱的余额/报警信并解析金额。")
                .font(.system(size: 11))
                .foregroundStyle(SBTheme.muted)

            if model.settings.mailSources.isEmpty {
                Text("暂无邮件源")
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

            Divider().overlay(SBTheme.stroke)

            Text("添加邮件源")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SBTheme.muted)

            TextField("显示名称", text: $mailName)
                .textFieldStyle(.roundedBorder)
            TextField("发件人包含（必填）", text: $mailFrom)
                .textFieldStyle(.roundedBorder)
            TextField("主题包含（可选）", text: $mailSubject)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("单位", text: $mailUnit)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 64)
                TextField("金额正则（可选）", text: $mailRegex)
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
            Button("试解析") { parseTarget = src }
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
}
