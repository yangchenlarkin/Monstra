// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AlamofireDownloader",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    dependencies: [
        .package(url: "https://github.com/yangchenlarkin/Monstra.git", from: "0.0.5"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")
    ],
    targets: [
        .executableTarget(
            name: "AlamofireDownloader",
            dependencies: [
                "Monstra",
                "Alamofire"
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "AlamofireDownloaderTests",
            dependencies: ["AlamofireDownloader"],
            path: "Tests"
        )
    ]
)
