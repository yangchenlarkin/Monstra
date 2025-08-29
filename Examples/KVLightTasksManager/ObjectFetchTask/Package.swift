// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ObjectFetchTask",
    platforms: [
        .iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        .executable(name: "ObjectFetchTask", targets: ["ObjectFetchTask"]) 
    ],
    dependencies: [
        .package(path: "../../../")
    ],
    targets: [
        .executableTarget(
            name: "ObjectFetchTask",
            dependencies: ["Monstra"],
            path: "Sources/ObjectFetchTask"
        )
    ]
)


