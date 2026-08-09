import Foundation

/// 下载后的 .pkg 静默安装：解包 → 退出后 ditto 覆盖当前 App → 自动重新打开。
/// 不弹 Installer 向导、不弹确认框；需要当前安装目录可写（本机 ad-hoc 安装通常可写）。
public enum PackageSilentInstaller: Sendable {
    public enum InstallError: Error, LocalizedError, Sendable {
        case expandFailed(String)
        case appNotFound
        case notWritable(String)
        case scriptFailed(String)

        public var errorDescription: String? {
            switch self {
            case .expandFailed(let s): "解包失败：\(s)"
            case .appNotFound: "安装包内未找到 App"
            case .notWritable(let p): "无法写入 \(p)（请确认智余装在「应用程序」且当前用户可写）"
            case .scriptFailed(let s): s
            }
        }
    }

    /// 解包 pkg，调度替换脚本后立即返回；调用方应随后退出 App。
    public static func scheduleReplace(
        pkgURL: URL,
        destinationApp: URL = Bundle.main.bundleURL
    ) throws {
        let fm = FileManager.default
        let work = fm.temporaryDirectory
            .appendingPathComponent("smartbalance-update-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)

        let expanded = work.appendingPathComponent("expanded", isDirectory: true)
        try runPkgUtilExpand(pkg: pkgURL, to: expanded)

        guard let newApp = findAppBundle(in: expanded) else {
            try? fm.removeItem(at: work)
            throw InstallError.appNotFound
        }

        let destDir = destinationApp.deletingLastPathComponent()
        guard fm.isWritableFile(atPath: destDir.path) || fm.isWritableFile(atPath: destinationApp.path) else {
            try? fm.removeItem(at: work)
            throw InstallError.notWritable(destinationApp.path)
        }

        let pid = ProcessInfo.processInfo.processIdentifier
        let scriptURL = work.appendingPathComponent("apply.sh")
        let logURL = (fm.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory)
            .appendingPathComponent("Logs/SmartBalance", isDirectory: true)
        try? fm.createDirectory(at: logURL, withIntermediateDirectories: true)
        let logFile = logURL.appendingPathComponent("update.log")

        let script = """
        #!/bin/bash
        set -e
        NEW=\(shellEscape(newApp.path))
        DEST=\(shellEscape(destinationApp.path))
        WORK=\(shellEscape(work.path))
        LOG=\(shellEscape(logFile.path))
        PID=\(pid)
        {
          echo "$(date '+%Y-%m-%d %H:%M:%S') update start pid=$PID"
          # 等旧进程退出
          for i in $(seq 1 100); do
            if ! kill -0 "$PID" 2>/dev/null; then
              break
            fi
            sleep 0.2
          done
          sleep 0.6
          if [ ! -d "$NEW" ]; then
            echo "missing new app: $NEW"
            exit 1
          fi
          # 先挪走旧包再覆盖，避免运行中残留
          OLD="${DEST}.preupdate"
          rm -rf "$OLD"
          if [ -e "$DEST" ]; then
            mv "$DEST" "$OLD" || rm -rf "$DEST"
          fi
          /usr/bin/ditto --norsrc --noextattr --noqtn "$NEW" "$DEST"
          /usr/bin/xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
          rm -rf "$OLD"
          /usr/bin/open "$DEST"
          echo "update ok → $DEST"
          rm -rf "$WORK"
        } >>"$LOG" 2>&1
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        // 后台子 shell，父进程退出后仍继续
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = ["-c", "nohup \(shellEscape(scriptURL.path)) >/dev/null 2>&1 &"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        // 不 wait：让 apply.sh 在后台跑
        AppLog.info("Silent PKG install scheduled → \(destinationApp.path)")
    }

    // MARK: - Expand

    private static func runPkgUtilExpand(pkg: URL, to dir: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: dir.path) {
            try fm.removeItem(at: dir)
        }
        // --expand-full 会展开 Payload
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/pkgutil")
        p.arguments = ["--expand-full", pkg.path, dir.path]
        let err = Pipe()
        p.standardError = err
        p.standardOutput = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
        } catch {
            throw InstallError.expandFailed(error.localizedDescription)
        }
        if p.terminationStatus == 0 { return }

        // 回退：--expand + 手动解 Payload
        let p2 = Process()
        p2.executableURL = URL(fileURLWithPath: "/usr/sbin/pkgutil")
        p2.arguments = ["--expand", pkg.path, dir.path]
        let err2 = Pipe()
        p2.standardError = err2
        p2.standardOutput = Pipe()
        try p2.run()
        p2.waitUntilExit()
        if p2.terminationStatus != 0 {
            let msg = String(data: err2.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "pkgutil failed"
            throw InstallError.expandFailed(msg)
        }
        try extractPayloadIfNeeded(in: dir)
    }

    private static func extractPayloadIfNeeded(in expanded: URL) throws {
        let fm = FileManager.default
        let payload = expanded.appendingPathComponent("Payload")
        guard fm.fileExists(atPath: payload.path) else {
            // 嵌套 component.pkg
            if let sub = try? fm.contentsOfDirectory(at: expanded, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "pkg" })
            {
                try extractPayloadIfNeeded(in: sub)
            }
            return
        }
        // 已是目录则无需再解
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: payload.path, isDirectory: &isDir), isDir.boolValue {
            return
        }
        let root = expanded.appendingPathComponent("PayloadRoot", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let cmd = """
        cd \(shellEscape(root.path)) && \
        /usr/bin/ditto -x \(shellEscape(payload.path)) . 2>/dev/null || \
        ( /usr/bin/gunzip -dc \(shellEscape(payload.path)) | /usr/bin/cpio -i 2>/dev/null )
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", cmd]
        try p.run()
        p.waitUntilExit()
    }

    private static func findAppBundle(in root: URL) -> URL? {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        var candidates: [URL] = []
        for case let url as URL in en {
            guard url.pathExtension == "app" else { continue }
            // 跳过嵌套过深的无关 app
            candidates.append(url)
        }
        // 优先 智余.app / 含 SmartBalance
        if let hit = candidates.first(where: { $0.lastPathComponent == "智余.app" }) {
            return hit
        }
        if let hit = candidates.first(where: { $0.lastPathComponent.lowercased().contains("smartbalance") }) {
            return hit
        }
        return candidates.first
    }

    private static func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
