// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SwiftlyKitCLI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "swiftlykit",
            targets: ["SwiftlyKitCLIExecutable"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/mottzi/SwiftlyKit.git",
            from: "0.5.1"
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            exact: "1.8.2"
        )
    ],
    targets: [
        .target(
            name: "SwiftlyKitCLI",
            dependencies: [
                .product(name: "SwiftlyKit", package: "SwiftlyKit"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(
            name: "SwiftlyKitCLIExecutable",
            dependencies: ["SwiftlyKitCLI"]
        ),
        .testTarget(
            name: "SwiftlyKitCLITests",
            dependencies: ["SwiftlyKitCLI"]
        )
    ],
    swiftLanguageModes: [.v6]
)
