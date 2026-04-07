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
                        additionalProperties: .bool(false),
                        title: "Point"
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
                        additionalProperties: .bool(false),
                        title: "User"
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
                        additionalProperties: .bool(false),
                        title: "Config"
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
                        additionalProperties: .bool(false),
                        title: "Tags"
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
                        additionalProperties: .bool(false),
                        title: "Team"
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
                        additionalProperties: .bool(false),
                        title: "Partial"
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - CodingKeys support

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
                        additionalProperties: .bool(false),
                        title: "Snake"
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - String enum → enumValues

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
                        additionalProperties: .bool(false),
                        title: "Order"
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
                DiagnosticSpec(message: "@JSONSchema can only be applied to a struct or enum", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    // MARK: - Date, URL, UUID types

    func test_struct_with_date_url_uuid() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct Event: Codable {
                let id: UUID
                let createdAt: Date
                let link: URL
            }
            """,
            expandedSource: """
            struct Event: Codable {
                let id: UUID
                let createdAt: Date
                let link: URL
            }

            extension Event: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [
                    "id": .string(description: "UUID"),
                    "createdAt": .string(description: "ISO 8601 date-time"),
                    "link": .string(description: "URL"),
                        ],
                        required: ["id", "createdAt", "link"],
                        additionalProperties: .bool(false),
                        title: "Event"
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Computed properties are skipped

    func test_computed_properties_are_excluded() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct Rectangle: Codable {
                let width: Double
                let height: Double
                var area: Double { width * height }
            }
            """,
            expandedSource: """
            struct Rectangle: Codable {
                let width: Double
                let height: Double
                var area: Double { width * height }
            }

            extension Rectangle: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [
                    "width": .number(),
                    "height": .number(),
                        ],
                        required: ["width", "height"],
                        additionalProperties: .bool(false),
                        title: "Rectangle"
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Zero stored properties

    func test_struct_with_no_stored_properties() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct Empty: Codable {
            }
            """,
            expandedSource: """
            struct Empty: Codable {
            }

            extension Empty: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [

                        ],
                        required: nil,
                        additionalProperties: .bool(false),
                        title: "Empty"
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - UInt, Float types

    func test_uint_and_float_types() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct Metrics: Codable {
                let count: UInt
                let ratio: Float
            }
            """,
            expandedSource: """
            struct Metrics: Codable {
                let count: UInt
                let ratio: Float
            }

            extension Metrics: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [
                    "count": .integer(),
                    "ratio": .number(),
                        ],
                        required: ["count", "ratio"],
                        additionalProperties: .bool(false),
                        title: "Metrics"
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - [String: Value] dictionary property

    func test_string_keyed_dictionary_property() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct Config: Codable {
                let metadata: [String: String]
            }
            """,
            expandedSource: """
            struct Config: Codable {
                let metadata: [String: String]
            }

            extension Config: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [
                    "metadata": .object(properties: [:], additionalProperties: .bool(true)),
                        ],
                        required: ["metadata"],
                        additionalProperties: .bool(false),
                        title: "Config"
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - #17 Default values → excluded from required

    func test_properties_with_defaults_excluded_from_required() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct Settings: Codable {
                let theme: String
                var debug: Bool = false
                var retries: Int = 3
            }
            """,
            expandedSource: """
            struct Settings: Codable {
                let theme: String
                var debug: Bool = false
                var retries: Int = 3
            }

            extension Settings: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [
                    "theme": .string(),
                    "debug": .boolean(),
                    "retries": .integer(),
                        ],
                        required: ["theme"],
                        additionalProperties: .bool(false),
                        title: "Settings"
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - #16 Set<T> → uniqueItems

    func test_set_property_generates_unique_items() {
        assertMacroExpansion(
            """
            @JSONSchema
            struct TagSet: Codable {
                let tags: Set<String>
            }
            """,
            expandedSource: """
            struct TagSet: Codable {
                let tags: Set<String>
            }

            extension TagSet: JSONConvertible {
                public static var jsonSchema: JSONSchema {
                    .object(
                        properties: [
                    "tags": .array(items: .string(), uniqueItems: true),
                        ],
                        required: ["tags"],
                        additionalProperties: .bool(false),
                        title: "TagSet"
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - #27 Top-level enum support (String raw-value)

    func test_string_enum_generates_schema_providing() {
        assertMacroExpansion(
            """
            @JSONSchema
            enum Color: String, Codable {
                case red
                case green
                case blue
            }
            """,
            expandedSource: """
            enum Color: String, Codable {
                case red
                case green
                case blue
            }

            extension Color: JSONSchemaProviding {
                public static var jsonSchema: JSONSchema {
                    .string(enumValues: ["red", "green", "blue"])
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - #27 Top-level enum support (associated values)

    func test_associated_value_enum_generates_one_of() {
        assertMacroExpansion(
            """
            @JSONSchema
            enum Result: Codable {
                case success(String)
                case failure(Int)
            }
            """,
            expandedSource: """
            enum Result: Codable {
                case success(String)
                case failure(Int)
            }

            extension Result: JSONSchemaProviding {
                public static var jsonSchema: JSONSchema {
                    .oneOf([
                        .object(properties: ["success": .string()], required: ["success"], additionalProperties: .bool(false)),
                        .object(properties: ["failure": .integer()], required: ["failure"], additionalProperties: .bool(false))
                    ])
                }
            }
            """,
            macros: testMacros
        )
    }
}
