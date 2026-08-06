import SwiftUI

struct IMAPSection: View {
    @ObservedObject var model: AppModel
    var embedded: Bool = false

    @State private var imapEnabled = false
    @State private var imapHost = ""
    @State private var imapPort = "993"
    @State private var imapTLS = true
    @State private var imapUser = ""
    @State private var imapPass = ""
    @State private var imapFolder = "INBOX"

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                SettingsChrome.card(title: "IMAP 收件箱") { content }
            }
        }
        .onAppear(perform: loadFields)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("启用 IMAP", isOn: $imapEnabled)
                .toggleStyle(.switch)
            TextField("IMAP 主机，如 imap.qq.com", text: $imapHost)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("端口", text: $imapPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Toggle("TLS（993）", isOn: $imapTLS)
                    .toggleStyle(.switch)
            }
            TextField("用户名 / 邮箱", text: $imapUser)
                .textFieldStyle(.roundedBorder)
            SecureField(model.hasIMAPPassword() ? "密码（留空不改）" : "密码 / 授权码", text: $imapPass)
                .textFieldStyle(.roundedBorder)
            TextField("文件夹", text: $imapFolder)
                .textFieldStyle(.roundedBorder)
            Button("保存 IMAP") {
                model.saveInboundMailbox(
                    enabled: imapEnabled,
                    host: imapHost,
                    port: Int(imapPort) ?? 993,
                    useTLS: imapTLS,
                    username: imapUser,
                    password: imapPass,
                    folder: imapFolder
                )
                imapPass = ""
            }
            .buttonStyle(SBButtonStyle(kind: .accent))
            Text("与下方 SMTP 报警可用同一邮箱，也可分开。")
                .font(.system(size: 10))
                .foregroundStyle(SBTheme.muted)
        }
    }

    private func loadFields() {
        let box = model.settings.inboundMailbox
        imapEnabled = box.enabled
        imapHost = box.imapHost
        imapPort = String(box.imapPort)
        imapTLS = box.useTLS
        imapUser = box.username
        imapFolder = box.folder
    }
}
