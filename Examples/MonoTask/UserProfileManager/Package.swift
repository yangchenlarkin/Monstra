// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UserProfileManager",
    platforms: [
        .iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        .executable(name: "UserProfileManager", targets: ["UserProfileManager"]) 
    ],
    dependencies: [
        .package(path: "../../../")
    ],
    targets: [
        .executableTarget(
            name: "UserProfileManager",
            dependencies: ["Monstra"],
            path: "Sources/UserProfileManager"
        )
    ]
)



