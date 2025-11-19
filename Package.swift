// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Szwitch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Szwitch", targets: ["Szwitch"]),
        .library(name: "SzwitchLib", targets: ["SzwitchLib"])
    ],
    targets: [
        .target(
            name: "SzwitchLib",
            path: "Sources/SzwitchLib"
        ),
        .executableTarget(
            name: "Szwitch",
            dependencies: ["SzwitchLib"],
            path: "Sources/Szwitch"
        ),
        .testTarget(
            name: "SzwitchTests",
            dependencies: ["SzwitchLib"],
            path: "Tests/SzwitchTests"
        )
    ]
)
