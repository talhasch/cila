// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Cila",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Cila",
            path: "Sources/Cila"
        ),
        .testTarget(
            name: "CilaTests",
            dependencies: ["Cila"],
            path: "Tests/CilaTests"
        ),
    ]
)
