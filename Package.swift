// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EverClip",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "CSQLite",
            path: "Sources/CSQLite"
        ),
        .executableTarget(
            name: "EverClip",
            dependencies: ["CSQLite"],
            path: "Sources/EverClip",
            linkerSettings: [
                .linkedFramework("Carbon"),
            ]
        ),
    ]
)
