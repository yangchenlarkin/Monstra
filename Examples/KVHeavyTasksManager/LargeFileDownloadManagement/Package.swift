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
        .package(path: "../../../"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        .package(url: "https://github.com/AFNetworking/AFNetworking.git", from: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "LargeFileDownloadManagement",
            dependencies: ["Monstra", "Alamofire", "AFNetworking"]
        )
    ]
)
