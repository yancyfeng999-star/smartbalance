import ProjectDescription

let project = Project(
    name: "SmartBalance",
    options: .options(
        defaultKnownRegions: ["en", "zh-Hans"],
        developmentRegion: "zh-Hans"
    ),
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "MACOSX_DEPLOYMENT_TARGET": "15.0",
            "ENABLE_DEBUG_DYLIB": "YES",
        ],
        debug: [
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
            "ENABLE_DEBUG_DYLIB": "YES",
        ],
        release: [
            "ENABLE_DEBUG_DYLIB": "NO",
            "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
            "SWIFT_OPTIMIZATION_LEVEL": "-O",
        ]
    ),
    targets: [
        .target(
            name: "Domain",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.smartbalance.domain",
            deploymentTargets: .macOS("15.0"),
            sources: ["Sources/Domain/**"],
            settings: .settings(base: [
                "SWIFT_STRICT_CONCURRENCY": "complete",
            ])
        ),
        .target(
            name: "Infrastructure",
            destinations: .macOS,
            product: .staticFramework,
            bundleId: "com.smartbalance.infrastructure",
            deploymentTargets: .macOS("15.0"),
            sources: ["Sources/Infrastructure/**"],
            dependencies: [
                .target(name: "Domain"),
            ],
            settings: .settings(base: [
                "SWIFT_STRICT_CONCURRENCY": "complete",
            ])
        ),
        .target(
            name: "SmartBalance",
            destinations: .macOS,
            product: .app,
            bundleId: "com.smartbalance.zhiyu",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .file(path: "Sources/App/Info.plist"),
            sources: ["Sources/App/**", "Tuist/.build/checkouts/MenuBarExtraAccess/Sources/MenuBarExtraAccess/**"],
            resources: [
                "Sources/App/Resources/**",
            ],
            entitlements: .file(path: "Sources/App/entitlements.plist"),
            dependencies: [
                .target(name: "Domain"),
                .target(name: "Infrastructure"),
            ],
            settings: .settings(
                base: [
                    "PRODUCT_NAME": "智余",
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                    "ENABLE_PREVIEWS": "NO",
                    "CODE_SIGN_IDENTITY": "-",
                    "CODE_SIGNING_ALLOWED": "YES",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "INFOPLIST_KEY_LSUIElement": "YES",
                    "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.utilities",
                ],
                debug: [
                    "ENABLE_DEBUG_DYLIB": "NO",
                ],
                release: [
                    "ENABLE_DEBUG_DYLIB": "NO",
                ]
            )
        ),
        .target(
            name: "DomainTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.smartbalance.domain-tests",
            deploymentTargets: .macOS("15.0"),
            sources: ["Tests/DomainTests/**"],
            dependencies: [
                .target(name: "Domain"),
            ]
        ),
        .target(
            name: "InfrastructureTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.smartbalance.infrastructure-tests",
            deploymentTargets: .macOS("15.0"),
            sources: ["Tests/InfrastructureTests/**"],
            dependencies: [
                .target(name: "Infrastructure"),
                .target(name: "Domain"),
            ]
        ),
        .target(
            name: "AppTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.smartbalance.app-tests",
            deploymentTargets: .macOS("15.0"),
            sources: [
                "Sources/App/MenuBarStatusItemDriver.swift",
                "Tests/AppTests/**",
            ],
            resources: [
                "Sources/App/Resources/**",
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "SmartBalance",
            shared: true,
            buildAction: .buildAction(targets: [.target("SmartBalance")]),
            testAction: .targets(["DomainTests", "InfrastructureTests", "AppTests"]),
            runAction: .runAction(configuration: .debug, executable: .target("SmartBalance"))
        ),
        .scheme(
            name: "Domain",
            shared: true,
            buildAction: .buildAction(targets: [.target("Domain")]),
            testAction: .targets(["DomainTests"])
        ),
        .scheme(
            name: "Infrastructure",
            shared: true,
            buildAction: .buildAction(targets: [.target("Infrastructure")]),
            testAction: .targets(["InfrastructureTests"])
        ),
    ]
)
