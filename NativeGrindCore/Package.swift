// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NativeGrindCore",
    platforms: [
        .watchOS(.v10),
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "NativeGrindCore",
            targets: ["NativeGrindCore"]
        ),
    ],
    targets: [
        .target(
            name: "NativeGrindCore",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "NativeGrindCoreTests",
            dependencies: ["NativeGrindCore"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ],
    swiftLanguageModes: [.v6]
)
