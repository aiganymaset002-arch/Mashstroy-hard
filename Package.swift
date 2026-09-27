// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MashstroyAI",
    defaultLocalization: "ru",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "MashstroyCore", targets: ["MashstroyCore"]),
        .library(name: "MashstroyCloud", targets: ["MashstroyCloud"]),
        .library(name: "MashstroyUI", targets: ["MashstroyUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.55.0")
    ],
    targets: [
        .target(name: "MashstroyCore"),
        .target(name: "MashstroyCloud", dependencies: [
            "MashstroyCore",
            .product(name: "Supabase", package: "supabase-swift")
        ]),
        .target(name: "MashstroyUI", dependencies: ["MashstroyCore", "MashstroyCloud"]),
        .testTarget(name: "MashstroyCoreTests", dependencies: ["MashstroyCore"])
    ]
)
