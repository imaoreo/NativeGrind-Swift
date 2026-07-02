// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NativeGrindServer",
    platforms: [
        .watchOS(.v10),
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "NativeGrindServer",
            targets: ["NativeGrindServer"]
        ),
    ],
    dependencies: [
        .package(path: "../NativeGrindCore")
    ],
    targets: [
        .target(
            name: "NativeGrindServer",
            dependencies: [
                .product(name: "NativeGrindCore", package: "NativeGrindCore"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "NativeGrindServerTests",
            dependencies: ["NativeGrindServer"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
    ]
)
