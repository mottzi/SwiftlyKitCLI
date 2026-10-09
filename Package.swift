// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "TripleCLI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "triple",
            targets: ["TripleCLIExecutable"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/mottzi/Triple.git",
            revision: "99c216dda112be33f7359d3fd5bf8d0334f20498"
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            exact: "1.8.2"
        )
    ],
    targets: [
        .target(
            name: "TripleCLI",
            dependencies: [
                .product(name: "Triple", package: "Triple"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(
            name: "TripleCLIExecutable",
            dependencies: ["TripleCLI"]
        ),
        .testTarget(
            name: "TripleCLITests",
            dependencies: ["TripleCLI"]
        )
    ],
    swiftLanguageModes: [.v6]
)
