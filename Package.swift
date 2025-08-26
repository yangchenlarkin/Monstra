// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Monstra",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        // Main unified Monstra library
        .library(
            name: "Monstra",
            targets: ["Monstra"]),
        // Example executable
        .executable(
            name: "KVHeavyTaskDataProviderExample",
            targets: ["KVHeavyTaskDataProviderExample"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0"),
    ],
    targets: [
        // Main unified Monstra target with all source files
        .target(
            name: "Monstra",
            dependencies: [],
            path: "Sources",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
            ]),
        // Example executable target
        .executableTarget(
            name: "KVHeavyTaskDataProviderExample",
            dependencies: ["Monstra", "Alamofire"],
            path: "Examples/KVHeavyTaskDataProviderExample",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]),
        .testTarget(
            name: "MonstraBaseTests",
            dependencies: ["Monstra"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]),
        .testTarget(
            name: "MonstoreTests",
            dependencies: ["Monstra"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]),
        .testTarget(
            name: "MonstaskTests",
            dependencies: ["Monstra"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]),
    ]
)
