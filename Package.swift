// swift-tools-version: 5.9

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "JSON.swift",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
        .watchOS(.v7),
        .tvOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "JSON",
            targets: ["JSON"]
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
            name: "JSON",
            dependencies: [
                // The macro plugin is a compiler-plugin (not runtime code) and works on all
                // platforms Swift macros are supported, including Linux (Swift 5.9+).
                .target(name: "JSONMacroPlugin"),
            ]
        ),

        // Macro logic (SwiftSyntax; not linked into app binaries).
        .target(
            name: "JSONMacros",
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
            name: "JSONMacroPlugin",
            dependencies: [
                .target(name: "JSONMacros"),
                .product(name: "SwiftSyntaxMacros",  package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Test suite.
        .testTarget(
            name: "JSONTests",
            dependencies: [
                "JSON",
                .target(name: "JSONMacros"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
