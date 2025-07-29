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
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Monstore",
            targets: ["Monstore"]),
        .library(
            name: "Monstask",
            targets: ["Monstask"]),
        .library(
            name: "MonstraBase",
            targets: ["MonstraBase"]),
        // Example executable
        .executable(
            name: "KVHeavyTasksManagerExample",
            targets: ["KVHeavyTasksManagerExample"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MonstraBase",
            dependencies: [],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
            ]),
        .target(
            name: "Monstore",
            dependencies: ["MonstraBase"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
            ]),
        .target(
            name: "Monstask",
            dependencies: ["MonstraBase", "Monstore"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
            ]),
        // Example executable target
        .executableTarget(
            name: "KVHeavyTasksManagerExample",
            dependencies: ["Monstask", "Alamofire"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]),
        .testTarget(
            name: "MonstraBaseTests",
            dependencies: ["MonstraBase"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]),
        .testTarget(
            name: "MonstoreTests",
            dependencies: ["Monstore"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]),
        .testTarget(
            name: "MonstaskTests",
            dependencies: ["Monstask"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]),
    ]
)
