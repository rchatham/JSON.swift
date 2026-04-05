// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "JSON",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "JSON",
            targets: ["JSON"]
        ),
    ],
    targets: [
        .target(
            name: "JSON",
            path: "Sources/JSON"
        ),
        .testTarget(
            name: "JSONTests",
            dependencies: ["JSON"],
            path: "Tests/JSONTests"
        ),
    ]
)
