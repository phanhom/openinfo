// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "openinfo",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "openinfo",
            path: "Sources/openinfo",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "openinfoTests",
            dependencies: ["openinfo"],
            path: "Tests/openinfoTests"
        )
    ]
)
