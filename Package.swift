// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RailwayMonitor",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Sparkle does the update check, as in Squiggle. SwiftPM links it but
        // cannot embed a binary framework into an executable product, so
        // build.sh copies Sparkle.framework into the bundle by hand.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "RailwayMonitor",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/RailwayMonitor"
        )
    ]
)
