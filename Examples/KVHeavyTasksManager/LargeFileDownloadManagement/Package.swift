// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LargeFileDownloadManagement",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    dependencies: [
        .package(url: "https://github.com/yangchenlarkin/Monstra.git", from: "0.0.5")
    ],
    targets: [
        .executableTarget(
            name: "LargeFileDownloadManagement",
            dependencies: ["Monstra"]
        ),
        .testTarget(
            name: "LargeFileDownloadManagementTests",
            dependencies: ["LargeFileDownloadManagement"]
        )
    ]
)
