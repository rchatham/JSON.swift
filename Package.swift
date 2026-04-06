// swift-tools-version: 5.9

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "JSON.swift",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .watchOS(.v8),
        .tvOS(.v15),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "JSONKit",
            targets: ["JSONKit"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "510.0.0"
        ),
    ],
    targets: [
        // Core library — the only target consumers import.
        .target(
            name: "JSONKit",
            dependencies: [
                .target(
                    name: "JSONKitMacroPlugin",
                    condition: .when(platforms: [.macOS, .iOS, .watchOS, .tvOS, .visionOS, .macCatalyst])
                ),
            ]
        ),

        // Macro logic (SwiftSyntax; not linked into app binaries).
        .target(
            name: "JSONKitMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros",  package: "swift-syntax"),
                .product(name: "SwiftSyntax",         package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder",  package: "swift-syntax"),
                .product(name: "SwiftDiagnostics",    package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Compiler plugin entry-point executable.
        .macro(
            name: "JSONKitMacroPlugin",
            dependencies: [
                .target(name: "JSONKitMacros"),
                .product(name: "SwiftSyntaxMacros",  package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Test suite.
        .testTarget(
            name: "JSONKitTests",
            dependencies: [
                "JSONKit",
                .target(name: "JSONKitMacros"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
