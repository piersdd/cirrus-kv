// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "cirrus-kv",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "cirrus-kv",
            path: "Sources/cirrus-kv"
        )
    ]
)
