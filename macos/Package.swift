// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PolishMac",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "PolishMac", targets: ["PolishMacApp"]),
    ],
    targets: [
        .executableTarget(
            name: "PolishMacApp",
            path: "Sources/PolishMacApp",
        ),
    ]
)
