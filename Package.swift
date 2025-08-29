// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Monstra",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        // Main unified Monstra library
        .library(
            name: "Monstra",
            targets: ["Monstra"]
        ),

    ],
    dependencies: [
        // Dependencies declare other packages that this package produces, making them visible to other packages.
    ],
    targets: [
        // Main unified Monstra target with all source files
        .target(
            name: "Monstra",
            dependencies: [],
            path: "Sources",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
            ]
        ),

        .testTarget(
            name: "MonstraBaseTests",
            dependencies: ["Monstra"]
        ),
        .testTarget(
            name: "MonstoreTests",
            dependencies: ["Monstra"]
        ),
        .testTarget(
            name: "MonstaskTests",
            dependencies: ["Monstra"]
        ),
    ]
)
