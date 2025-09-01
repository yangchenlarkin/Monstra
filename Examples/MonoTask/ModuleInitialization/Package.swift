// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ModuleInitialization",
    platforms: [
        .iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        .executable(name: "ModuleInitialization", targets: ["ModuleInitialization"]) 
    ],
    dependencies: [
        .package(path: "../../../")
    ],
    targets: [
        .executableTarget(
            name: "ModuleInitialization",
            dependencies: ["Monstra"],
            path: "Sources/ModuleInitialization"
        )
    ]
)



