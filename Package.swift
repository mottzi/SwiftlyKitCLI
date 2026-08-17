// swift-tools-version: 6.3

import Foundation
import PackageDescription

let usesLocalSwiftlyKit = ProcessInfo.processInfo.environment["SWIFTLYKIT_USE_LOCAL_DEPENDENCY"] == "1"
let swiftlyKitDependency: Package.Dependency = usesLocalSwiftlyKit
    ? .package(path: "../SwiftlyKit")
    : .package(
        url: "https://github.com/mottzi/SwiftlyKit.git",
        exact: "0.3.1"
    )

let package = Package(
    name: "SwiftlyKitCLI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SwiftlyKitCLI",
            targets: ["SwiftlyKitCLI"]
        ),
        .executable(
            name: "swiftlykit",
            targets: ["SwiftlyKitCLIExecutable"]
        )
    ],
    dependencies: [
        swiftlyKitDependency,
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
