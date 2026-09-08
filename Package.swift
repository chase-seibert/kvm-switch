// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProArtKVM",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ProArtKVM", targets: ["ProArtKVM"])],
    targets: [
        .executableTarget(
            name: "ProArtKVM",
            path: "ProArtKVM",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit"),
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)
