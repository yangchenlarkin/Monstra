// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LargeFileUnzip",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    dependencies: [
        .package(path: "../../../"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.16"),
    ],
    targets: [
        .executableTarget(
            name: "LargeFileUnzip",
            dependencies: ["Monstra", "ZIPFoundation"]
        ),
    ]
)
