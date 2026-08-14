import XCTest
@testable import Domain
@testable import Infrastructure

final class PackageSilentInstallerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sb-pkg-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testValidationFailureDoesNotInstallOrTouchAppAndSettings() throws {
        let env = try SeededInstall(directory: directory)
        let originalApp = try Data(contentsOf: env.infoPlist)
        let originalSettings = try Data(contentsOf: env.settings)
        let expandBox = CallBox()
        let launchBox = CallBox()

        XCTAssertThrowsError(
            try PackageSilentInstaller.scheduleReplace(
                pkgURL: env.pkg,
                destinationApp: env.app,
                candidate: env.badCandidate,
                environment: PackageInstallEnvironment(
                    inspector: StubInspector(structureValid: true, signatureValid: true),
                    expandPackage: { _, _ in
                        expandBox.called = true
                        return env.app
                    },
                    launchApplyScript: { _ in
                        launchBox.called = true
                    }
                )
            )
        ) { error in
            let install = error as? PackageSilentInstaller.InstallError
            guard case .validationFailed(let issue) = install else {
                return XCTFail("expected validationFailed, got \(error)")
            }
            XCTAssertEqual(issue, .versionNotNewer)
            XCTAssertEqual(install?.localizationKey, UpdateValidationIssue.versionNotNewer.localizationKey)
        }

        XCTAssertFalse(expandBox.called)
        XCTAssertFalse(launchBox.called)
        XCTAssertEqual(try Data(contentsOf: env.infoPlist), originalApp)
        XCTAssertEqual(try Data(contentsOf: env.settings), originalSettings)
        XCTAssertFalse(FileManager.default.fileExists(atPath: env.app.path + ".preupdate"))
        XCTAssertEqual(SeededInstall.workDirectoryCount(), env.workCountBefore)
    }

    func testInvalidSignatureDoesNotInstall() throws {
        let env = try SeededInstall(directory: directory)
        let originalApp = try Data(contentsOf: env.infoPlist)
        let expandBox = CallBox()

        XCTAssertThrowsError(
            try PackageSilentInstaller.scheduleReplace(
                pkgURL: env.pkg,
                destinationApp: env.app,
                candidate: env.goodCandidate,
                environment: PackageInstallEnvironment(
                    inspector: StubInspector(structureValid: true, signatureValid: false),
                    expandPackage: { _, _ in
                        expandBox.called = true
                        return env.app
                    },
                    launchApplyScript: { _ in }
                )
            )
        ) { error in
            guard case .validationFailed(let issue) = error as? PackageSilentInstaller.InstallError else {
                return XCTFail("expected validationFailed, got \(error)")
            }
            XCTAssertEqual(issue, .packageSignatureInvalid)
        }
        XCTAssertFalse(expandBox.called)
        XCTAssertEqual(try Data(contentsOf: env.infoPlist), originalApp)
    }

    func testExpandFailureCleansWorkspaceAndLeavesApp() throws {
        let env = try SeededInstall(directory: directory)
        let originalApp = try Data(contentsOf: env.infoPlist)
        let originalSettings = try Data(contentsOf: env.settings)

        XCTAssertThrowsError(
            try PackageSilentInstaller.scheduleReplace(
                pkgURL: env.pkg,
                destinationApp: env.app,
                candidate: env.goodCandidate,
                environment: PackageInstallEnvironment(
                    inspector: StubInspector(structureValid: true, signatureValid: true),
                    expandPackage: { _, _ in
                        throw PackageSilentInstaller.InstallError.expandFailed("boom")
                    },
                    launchApplyScript: { _ in
                        XCTFail("script should not run")
                    }
                )
            )
        ) { error in
            guard case .expandFailed = error as? PackageSilentInstaller.InstallError else {
                return XCTFail("expected expandFailed, got \(error)")
            }
            XCTAssertEqual(
                (error as? PackageSilentInstaller.InstallError)?.localizationKey,
                "update.error.expandFailed"
            )
        }

        XCTAssertEqual(try Data(contentsOf: env.infoPlist), originalApp)
        XCTAssertEqual(try Data(contentsOf: env.settings), originalSettings)
        XCTAssertEqual(SeededInstall.workDirectoryCount(), env.workCountBefore)
    }

    func testScriptFailureCleansTemporaryWorkspaceAndLeavesApp() throws {
        let env = try SeededInstall(directory: directory)
        let originalApp = try Data(contentsOf: env.infoPlist)
        let originalSettings = try Data(contentsOf: env.settings)

        XCTAssertThrowsError(
            try PackageSilentInstaller.scheduleReplace(
                pkgURL: env.pkg,
                destinationApp: env.app,
                candidate: env.goodCandidate,
                environment: PackageInstallEnvironment(
                    inspector: StubInspector(structureValid: true, signatureValid: true),
                    expandPackage: { _, work in
                        let newApp = work.appendingPathComponent("智余.app")
                        try FileManager.default.createDirectory(at: newApp, withIntermediateDirectories: true)
                        return newApp
                    },
                    launchApplyScript: { _ in
                        throw PackageSilentInstaller.InstallError.scriptFailed("no")
                    }
                )
            )
        ) { error in
            guard case .scriptFailed = error as? PackageSilentInstaller.InstallError else {
                return XCTFail("expected scriptFailed, got \(error)")
            }
            XCTAssertEqual(
                (error as? PackageSilentInstaller.InstallError)?.localizationKey,
                "update.error.installScriptFailed"
            )
        }

        XCTAssertEqual(try Data(contentsOf: env.infoPlist), originalApp)
        XCTAssertEqual(try Data(contentsOf: env.settings), originalSettings)
        XCTAssertEqual(SeededInstall.workDirectoryCount(), env.workCountBefore)
    }

    func testSuccessfulScheduleKeepsPreupdateInScript() throws {
        let env = try SeededInstall(directory: directory)
        let scriptBox = StringBox()
        try PackageSilentInstaller.scheduleReplace(
            pkgURL: env.pkg,
            destinationApp: env.app,
            candidate: env.goodCandidate,
            environment: PackageInstallEnvironment(
                inspector: StubInspector(structureValid: true, signatureValid: true),
                expandPackage: { _, work in
                    let newApp = work.appendingPathComponent("智余.app")
                    try FileManager.default.createDirectory(at: newApp, withIntermediateDirectories: true)
                    return newApp
                },
                launchApplyScript: { url in
                    scriptBox.value = try String(contentsOf: url, encoding: .utf8)
                }
            )
        )
        XCTAssertTrue(scriptBox.value.contains(".preupdate"))
        let afterDitto = scriptBox.value.components(separatedBy: "/usr/bin/ditto").last ?? ""
        XCTAssertFalse(afterDitto.contains("rm -rf \"$OLD\""))
        XCTAssertTrue(FileManager.default.fileExists(atPath: env.app.path))
        if let work = scriptBox.value.split(separator: "\n").first(where: { $0.contains("WORK=") }) {
            let path = work.replacingOccurrences(of: "WORK=", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}

private struct StubInspector: PackageIntegrityInspecting {
    var structureValid: Bool
    var signatureValid: Bool?

    func inspect(fileURL: URL) -> PackageIntegrityReport {
        PackageIntegrityReport(structureValid: structureValid, signatureValid: signatureValid)
    }
}

private final class CallBox: @unchecked Sendable {
    var called = false
}

private final class StringBox: @unchecked Sendable {
    var value = ""
}

private struct SeededInstall {
    var app: URL
    var infoPlist: URL
    var settings: URL
    var pkg: URL
    var goodCandidate: UpdateCandidate
    var badCandidate: UpdateCandidate
    var directory: URL
    var workCountBefore: Int

    init(directory: URL) throws {
        self.directory = directory
        self.workCountBefore = SeededInstall.workDirectoryCount()
        app = directory.appendingPathComponent("智余.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        infoPlist = contents.appendingPathComponent("Info.plist")
        try Data("original-app".utf8).write(to: infoPlist)
        settings = directory.appendingPathComponent("settings.json")
        try Data("{\"themeMode\":\"dark\"}".utf8).write(to: settings)
        pkg = directory.appendingPathComponent("SmartBalance-0.3.2.pkg")
        var bytes = Data("xar!".utf8)
        bytes.append(Data(repeating: 0x01, count: 64))
        try bytes.write(to: pkg)
        let url = URL(string: "https://github.com/yancyfeng999-star/smartbalance/releases/download/v0.3.2/SmartBalance-0.3.2.pkg")!
        goodCandidate = UpdateCandidate(
            currentVersion: "0.3.1",
            targetVersion: "0.3.2",
            minimumMacOS: "15.0",
            currentMacOS: "15.6.0",
            assetURL: url,
            assetFileName: "SmartBalance-0.3.2.pkg",
            assetByteSize: Int64(bytes.count),
            downloadedFileURL: pkg
        )
        badCandidate = UpdateCandidate(
            currentVersion: "0.3.2",
            targetVersion: "0.3.1",
            minimumMacOS: "15.0",
            currentMacOS: "15.6.0",
            assetURL: url,
            assetFileName: "SmartBalance-0.3.2.pkg",
            assetByteSize: Int64(bytes.count),
            downloadedFileURL: pkg
        )
    }

    static func workDirectoryCount() -> Int {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: FileManager.default.temporaryDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        return items.filter { $0.lastPathComponent.hasPrefix("smartbalance-update-") }.count
    }
}
