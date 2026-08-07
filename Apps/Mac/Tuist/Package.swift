// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [:]
)
#endif

let package = Package(
    name: "SmartBalance",
    dependencies: [
        // 拿到 MenuBarExtra 底层 NSStatusItem，用 AppKit 画彩色透明 Logo（避免 SwiftUI 方块底）
        .package(url: "https://github.com/orchetect/MenuBarExtraAccess", from: "1.3.0"),
    ]
)
