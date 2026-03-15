// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "icloud-kv",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "icloud-kv",
            path: "Sources/icloud-kv"
        )
    ]
)
