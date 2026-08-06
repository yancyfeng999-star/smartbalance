import SwiftUI
import Domain

/// 粘贴平台邮件主题/正文，试解析金额；可选写入该源的 `lastParsedAmount`。
struct PasteMailParseSheet: View {
    let source: PlatformMailSource
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var subject = ""
    @State private var bodyText = ""
    @State private var result: BalanceSnapshot?
    @State private var isParsing = false
    @State private var writeBanner: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            fields
            actions
            resultBlock
            Spacer(minLength: 0)
            footer
        }
        .padding(16)
        .frame(minWidth: 400, idealWidth: 420, minHeight: 460)
        .background(SBTheme.bg)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("试解析 · \(source.displayName)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SBTheme.text)
            Text("粘贴平台发来的邮件主题与正文，用该源的金额正则提取余额。")
                .font(.system(size: 11))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if !source.amountRegex.isEmpty {
                Text("自定义正则：\(source.amountRegex)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SBTheme.muted)
            }
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("主题")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
            TextField("邮件主题（可选）", text: $subject)
                .textFieldStyle(.roundedBorder)

            Text("正文")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
            TextEditor(text: $bodyText)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 140, maxHeight: 200)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SBTheme.panel)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(SBTheme.stroke, lineWidth: 1)
                        )
                )
                .foregroundStyle(SBTheme.text)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                runParse()
            } label: {
                Text(isParsing ? "解析中…" : "解析")
            }
            .buttonStyle(SBButtonStyle(kind: .accent))
            .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing)

            if let amount = result?.amount {
                Button("写入为该源的上次金额") {
                    model.writeLastParsedAmount(sourceId: source.id, amount: amount)
                    writeBanner = "已写入 \(source.displayName)：\(result?.primaryText ?? "")"
                }
                .buttonStyle(SBButtonStyle(kind: .normal))
            }
        }
    }

    @ViewBuilder
    private var resultBlock: some View {
        if let writeBanner {
            Text(writeBanner)
                .font(.system(size: 11))
                .foregroundStyle(SBTheme.ok)
        }
        if let result {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("解析结果")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SBTheme.muted)
                    Spacer()
                    Text(result.status.titleCN)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SBTheme.statusColor(result.status))
                }

                Text(result.primaryText)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(SBTheme.text)

                if let err = result.errorMessage {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(SBTheme.danger)
                }

                Text(result.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(SBTheme.muted)

                if result.amount == nil {
                    Text("无数字匹配 · 请调整该源金额正则，或确认正文含「余额：¥12」一类文案。")
                        .font(.system(size: 11))
                        .foregroundStyle(SBTheme.warn)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(SBTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(SBTheme.statusColor(result.status).opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("关闭") { dismiss() }
                .buttonStyle(SBButtonStyle(kind: .normal))
        }
    }

    private func runParse() {
        isParsing = true
        writeBanner = nil
        Task {
            let snap = await model.parsePastedMail(
                source: source,
                subject: subject,
                body: bodyText
            )
            result = snap
            isParsing = false
        }
    }
}
