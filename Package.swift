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
        // Core library — JSON types, JSONSchema, validation, SchemaBuilder DSL.
        // Does NOT include the macro plugin, so Xcode will not prompt for macro trust.
        .library(
            name: "JSON",
            targets: ["JSON"]
        ),
        // Optional: adds the @JSONSchema macro on top of the core library.
        // Importing this product requires Xcode macro trust consent.
        .library(
            name: "JSONWithMacros",
            targets: ["JSONWithMacros"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "510.0.0"
        ),
    ],
    targets: [
        // Core library — no macro plugin dependency.
        // The @JSONSchema macro is declared here (declaration compiles fine without
        // the plugin linked; the plugin is only needed at macro expansion time).
        .target(
            name: "JSON"
        ),

        // Thin umbrella target that re-exports JSON + wires in the macro plugin.
        // Consumers who want @JSONSchema import JSONWithMacros instead of JSON.
        .target(
            name: "JSONWithMacros",
            dependencies: [
                .target(name: "JSON"),
                .target(name: "JSONMacroPlugin"),
            ]
        ),

        // Compiler plugin entry-point executable (also contains macro implementation).
        .macro(
            name: "JSONMacroPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros",  package: "swift-syntax"),
                .product(name: "SwiftSyntax",         package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder",  package: "swift-syntax"),
                .product(name: "SwiftDiagnostics",    package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Test suite.
        .testTarget(
            name: "JSONTests",
            dependencies: [
                "JSONWithMacros",
                .target(name: "JSONMacroPlugin"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
