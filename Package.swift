// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacClip",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacClip",
            path: "MacClip",
            exclude: [
                "Info.plist",
                "MacClip.entitlements",
                "Resources",
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
            ]
        )
    ]
)
