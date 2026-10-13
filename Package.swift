// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "mac-openstats",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "OpenStats", targets: ["OpenStats"])
    ],
    targets: [
        .executableTarget(
            name: "OpenStats",
            path: "Sources/OpenStats",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
