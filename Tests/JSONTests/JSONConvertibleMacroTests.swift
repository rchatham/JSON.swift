//
//  JSONConvertibleMacroTests.swift
//  JSONTests
//
//  Created by Reid Chatham on 4/5/25.
//

import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import JSONMacros

// MARK: - Macro expansion tests

final class JSONConvertibleMacroTests: XCTestCase {

    private let testMacros: [String: Macro.Type] = [
        "JSONSchema": JSONConvertibleMacro.self,
    ]

    // MARK: - Basic property types

    func test_simple_struct_all_required() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct Point: Codable {
                let x: Double
                let y: Double
            }
            """,
            expandedSource: """
            struct Point: Codable {
                let x: Double
                let y: Double
            }

            extension Point: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [
                    "x": .number(),
                    "y": .number(),
                        ],
                        required: ["x", "y"],
                        additionalProperties: false
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_struct_with_optional_property() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct User: Codable {
                let name: String
                let email: String?
            }
            """,
            expandedSource: """
            struct User: Codable {
                let name: String
                let email: String?
            }

            extension User: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [
                    "name": .string(),
                    "email": .string(),
                        ],
                        required: ["name"],
                        additionalProperties: false
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_struct_with_bool_and_int() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct Config: Codable {
                let enabled: Bool
                let count: Int
            }
            """,
            expandedSource: """
            struct Config: Codable {
                let enabled: Bool
                let count: Int
            }

            extension Config: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [
                    "enabled": .boolean(),
                    "count": .integer(),
                        ],
                        required: ["enabled", "count"],
                        additionalProperties: false
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_struct_with_array_property() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct Tags: Codable {
                let values: [String]
            }
            """,
            expandedSource: """
            struct Tags: Codable {
                let values: [String]
            }

            extension Tags: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [
                    "values": .array(items: .string()),
                        ],
                        required: ["values"],
                        additionalProperties: false
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_struct_with_nested_convertible() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct Team: Codable {
                let leader: Person
            }
            """,
            expandedSource: """
            struct Team: Codable {
                let leader: Person
            }

            extension Team: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [
                    "leader": .from(Person.self),
                        ],
                        required: ["leader"],
                        additionalProperties: false
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_struct_all_optional_has_nil_required() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct Partial: Codable {
                let x: String?
                let y: Int?
            }
            """,
            expandedSource: """
            struct Partial: Codable {
                let x: String?
                let y: Int?
            }

            extension Partial: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [
                    "x": .string(),
                    "y": .integer(),
                        ],
                        required: nil,
                        additionalProperties: false
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - CodingKeys support (#18)

    func test_struct_with_coding_keys() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct Snake: Codable {
                let firstName: String
                let lastName: String

                enum CodingKeys: String, CodingKey {
                    case firstName = "first_name"
                    case lastName = "last_name"
                }
            }
            """,
            expandedSource: """
            struct Snake: Codable {
                let firstName: String
                let lastName: String

                enum CodingKeys: String, CodingKey {
                    case firstName = "first_name"
                    case lastName = "last_name"
                }
            }

            extension Snake: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [
                    "first_name": .string(),
                    "last_name": .string(),
                        ],
                        required: ["first_name", "last_name"],
                        additionalProperties: false
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - String enum → enumValues (#19)

    func test_struct_with_string_enum_property() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct Order: Codable {
                enum Status: String, Codable {
                    case pending, processing, shipped
                }
                let id: Int
                let status: Status
            }
            """,
            expandedSource: """
            struct Order: Codable {
                enum Status: String, Codable {
                    case pending, processing, shipped
                }
                let id: Int
                let status: Status
            }

            extension Order: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [
                    "id": .integer(),
                    "status": .string(enumValues: ["pending", "processing", "shipped"]),
                        ],
                        required: ["id", "status"],
                        additionalProperties: false
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Non-struct guard (#17)

    func test_macro_on_class_emits_error() {
        assertMacroExpansion(
            """
            @JSONSchema
            class NotAStruct: Codable {
                let x: String = ""
            }
            """,
            expandedSource: """
            class NotAStruct: Codable {
                let x: String = ""
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@JSONSchema can only be applied to a struct", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
}
