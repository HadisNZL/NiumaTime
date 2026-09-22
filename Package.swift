// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FloatProgress",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FloatProgress", targets: ["FloatProgress"])
    ],
    targets: [
        .executableTarget(
            name: "FloatProgress",
            path: "Sources/FloatProgress"
        ),
        .testTarget(
            name: "FloatProgressTests",
            dependencies: ["FloatProgress"],
            path: "Tests/FloatProgressTests"
        )
    ]
)
