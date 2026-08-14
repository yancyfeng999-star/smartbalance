import Foundation
import XCTest

final class OpenSourceDocumentationTests: XCTestCase {
    func testRequiredOpenSourceDocumentsExist() throws {
        let root = try repositoryRoot()
        let required = [
            "LICENSE",
            "README.md",
            "CONTRIBUTING.md",
            "SECURITY.md",
            "CODE_OF_CONDUCT.md",
            "THIRD_PARTY_NOTICES.md",
            "docs/ARCHITECTURE.md",
            "docs/DATA_AND_PRIVACY.md",
            "docs/PROVIDER_DEVELOPMENT.md",
            "docs/RELEASE_CHECKLIST.md",
            ".github/PULL_REQUEST_TEMPLATE.md",
            ".github/ISSUE_TEMPLATE/bug_report.yml",
            ".github/ISSUE_TEMPLATE/feature_request.yml",
            "Apps/Mac/scripts/verify-open-source.sh",
        ]

        for path in required {
            let url = root.appendingPathComponent(path)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path),
                "缺少开源交付文件：\(path)"
            )
        }
    }

    func testLicenseDeclaresApacheAndSPDX() throws {
        let license = try String(contentsOf: repositoryRoot().appendingPathComponent("LICENSE"), encoding: .utf8)

        XCTAssertTrue(license.contains("Apache License"))
        XCTAssertTrue(license.contains("Version 2.0, January 2004"))
        XCTAssertTrue(license.contains("SPDX-License-Identifier: Apache-2.0"))
        XCTAssertTrue(license.contains("2. Grant of Copyright License"))
        XCTAssertTrue(license.contains("3. Grant of Patent License"))
        XCTAssertTrue(license.contains("END OF TERMS AND CONDITIONS"))
    }

    func testReadmeExposesContributorPrivacySecurityAndLicensePaths() throws {
        let readme = try String(contentsOf: repositoryRoot().appendingPathComponent("README.md"), encoding: .utf8)

        for marker in ["CONTRIBUTING.md", "SECURITY.md", "CODE_OF_CONDUCT.md", "THIRD_PARTY_NOTICES.md", "Apache-2.0"] {
            XCTAssertTrue(readme.contains(marker), "README 未公开入口：\(marker)")
        }
        XCTAssertTrue(readme.contains("本地"))
        XCTAssertTrue(readme.contains("Keychain"))
    }

    func testReadmeDocumentLinksResolve() throws {
        let root = try repositoryRoot()
        let readme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)
        let links = [
            "./LICENSE",
            "./CONTRIBUTING.md",
            "./SECURITY.md",
            "./CODE_OF_CONDUCT.md",
            "./THIRD_PARTY_NOTICES.md",
            "./docs/ARCHITECTURE.md",
            "./docs/DATA_AND_PRIVACY.md",
            "./docs/PROVIDER_DEVELOPMENT.md",
            "./docs/RELEASE_CHECKLIST.md",
        ]

        for link in links {
            XCTAssertTrue(readme.contains("](" + link + ")"), "README 缺少文档链接：" + link)
            let relativePath = String(link.dropFirst(2))
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path),
                "README 链接目标不存在：" + relativePath
            )
        }
    }

    func testThirdPartyNoticeCoversLockedRuntimeDependency() throws {
        let notices = try String(contentsOf: repositoryRoot().appendingPathComponent("THIRD_PARTY_NOTICES.md"), encoding: .utf8)

        XCTAssertTrue(notices.contains("MenuBarExtraAccess"))
        XCTAssertTrue(notices.contains("https://github.com/orchetect/MenuBarExtraAccess"))
        XCTAssertTrue(notices.contains("1.3.1"))
        XCTAssertTrue(notices.contains("MIT"))
    }

    func testPublicDocsDoNotContainThisCheckoutAbsolutePath() throws {
        let root = try repositoryRoot()
        let docs = [
            "README.md",
            "CONTRIBUTING.md",
            "SECURITY.md",
            "CODE_OF_CONDUCT.md",
            "THIRD_PARTY_NOTICES.md",
            "docs/ARCHITECTURE.md",
            "docs/DATA_AND_PRIVACY.md",
            "docs/PROVIDER_DEVELOPMENT.md",
            "docs/RELEASE_CHECKLIST.md",
        ]

        for path in docs {
            let content = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            XCTAssertFalse(content.contains("/Users/yancyfeng/"), "公开文档泄露了本机绝对路径：\(path)")
        }
    }

    func testOpenSourceGateScriptIsExecutable() throws {
        let script = try repositoryRoot().appendingPathComponent("Apps/Mac/scripts/verify-open-source.sh")
        let attributes = try FileManager.default.attributesOfItem(atPath: script.path)
        let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0

        XCTAssertNotEqual(mode & 0o111, 0, "开源门禁脚本必须可执行")
    }

    private func repositoryRoot() throws -> URL {
        var candidate = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        for _ in 0..<8 {
            let hasLicense = FileManager.default.fileExists(atPath: candidate.appendingPathComponent("LICENSE").path)
            let hasMacProject = FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Apps/Mac/Project.swift").path)
            if hasLicense && hasMacProject {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        throw XCTSkip("无法从测试源文件定位智余仓库根目录")
    }
}
