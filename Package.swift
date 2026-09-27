// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MashstroyAI",
    defaultLocalization: "ru",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "MashstroyCore", targets: ["MashstroyCore"]),
        .library(name: "MashstroyUI", targets: ["MashstroyUI"])
    ],
    targets: [
        .target(name: "MashstroyCore"),
        .target(name: "MashstroyUI", dependencies: ["MashstroyCore"]),
        .testTarget(name: "MashstroyCoreTests", dependencies: ["MashstroyCore"])
    ]
)
