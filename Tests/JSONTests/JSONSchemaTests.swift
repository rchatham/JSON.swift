//
//  JSONSchemaTests.swift
//  JSONTests
//
//  Created by Reid Chatham on 4/5/25.
//

import XCTest
@testable import JSON

final class JSONSchemaTests: XCTestCase {

    // MARK: - Factory Methods — Primitives

    func test_string_schema() {
        let schema = JSONSchema.string()
        XCTAssertEqual(schema.type, .string)
        XCTAssertNil(schema.enumValues)
    }

    func test_string_schema_with_description_and_enum() {
        let schema = JSONSchema.string(description: "A color", enumValues: ["red", "green", "blue"])
        XCTAssertEqual(schema.type, .string)
        XCTAssertEqual(schema.schemaDescription, "A color")
        XCTAssertEqual(schema.enumValues, ["red", "green", "blue"])
    }

    func test_number_schema() {
        let schema = JSONSchema.number(description: "A price")
        XCTAssertEqual(schema.type, .number)
        XCTAssertEqual(schema.schemaDescription, "A price")
    }

    func test_integer_schema() {
        XCTAssertEqual(JSONSchema.integer().type, .integer)
    }

    func test_boolean_schema() {
        XCTAssertEqual(JSONSchema.boolean().type, .boolean)
    }

    func test_null_schema() {
        XCTAssertEqual(JSONSchema.null().type, .null)
    }

    func test_array_schema() {
        let schema = JSONSchema.array(items: .string(), description: "Tags")
        XCTAssertEqual(schema.type, .array)
        XCTAssertEqual(schema.items?.type, .string)
        XCTAssertEqual(schema.schemaDescription, "Tags")
    }

    func test_object_schema() {
        let schema = JSONSchema.object(
            properties: ["name": .string()],
            required: ["name"],
            additionalProperties: false,
            description: "A person",
            title: "Person"
        )
        XCTAssertEqual(schema.type, .object)
        XCTAssertNotNil(schema.properties?["name"])
        XCTAssertEqual(schema.required, ["name"])
        XCTAssertEqual(schema.additionalProperties, false)
        XCTAssertEqual(schema.schemaDescription, "A person")
        XCTAssertEqual(schema.title, "Person")
    }

    // MARK: - Factory Methods — Composition

    func test_anyOf_schema() {
        let schema = JSONSchema.anyOf([.string(), .null()])
        XCTAssertNil(schema.type)
        XCTAssertEqual(schema.anyOf?.count, 2)
        XCTAssertEqual(schema.anyOf?[0].type, .string)
        XCTAssertEqual(schema.anyOf?[1].type, .null)
    }

    func test_oneOf_schema() {
        let schema = JSONSchema.oneOf([.string(), .integer()])
        XCTAssertNil(schema.type)
        XCTAssertEqual(schema.oneOf?.count, 2)
    }

    func test_allOf_schema() {
        let schema = JSONSchema.allOf([.object(properties: ["a": .string()]), .object(properties: ["b": .number()])])
        XCTAssertEqual(schema.allOf?.count, 2)
    }

    func test_nullable_convenience() {
        let schema = JSONSchema.string().nullable
        XCTAssertEqual(schema.anyOf?.count, 2)
        XCTAssertEqual(schema.anyOf?[0].type, .string)
        XCTAssertEqual(schema.anyOf?[1].type, .null)
    }

    // MARK: - Codable Round-trip

    func test_string_schema_roundtrip() throws {
        let schema = JSONSchema.string(description: "greeting", enumValues: ["hello", "bye"])
        let decoded = try JSONDecoder().decode(JSONSchema.self, from: JSONEncoder().encode(schema))
        XCTAssertEqual(decoded, schema)
    }

    func test_object_schema_roundtrip() throws {
        let schema = JSONSchema.object(
            properties: ["id": .integer(), "name": .string(), "tags": .array(items: .string())],
            required: ["id", "name"],
            additionalProperties: false,
            title: "Item"
        )
        let decoded = try JSONDecoder().decode(JSONSchema.self, from: JSONEncoder().encode(schema))
        XCTAssertEqual(decoded, schema)
    }

    func test_nested_object_schema_roundtrip() throws {
        let inner = JSONSchema.object(properties: ["x": .number()])
        let outer = JSONSchema.object(properties: ["inner": inner], required: ["inner"])
        let decoded = try JSONDecoder().decode(JSONSchema.self, from: JSONEncoder().encode(outer))
        XCTAssertEqual(decoded, outer)
    }

    func test_anyOf_schema_roundtrip() throws {
        let schema = JSONSchema.anyOf([.string(), .null()], description: "nullable string")
        let decoded = try JSONDecoder().decode(JSONSchema.self, from: JSONEncoder().encode(schema))
        XCTAssertEqual(decoded, schema)
    }

    // MARK: - CodingKeys mapping

    func test_enum_coding_key_is_enum() throws {
        let schema = JSONSchema.string(enumValues: ["a", "b"])
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(schema)) as? [String: Any]
        )
        XCTAssertNotNil(json["enum"])
        XCTAssertNil(json["enumValues"])
    }

    func test_description_coding_key_is_description() throws {
        let schema = JSONSchema.string(description: "a desc")
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(schema)) as? [String: Any]
        )
        XCTAssertNotNil(json["description"])
        XCTAssertNil(json["schemaDescription"])
    }

    // MARK: - CustomStringConvertible

    func test_description_is_valid_json() throws {
        let schema = JSONSchema.object(properties: ["x": .boolean()], required: ["x"])
        let str = schema.description
        XCTAssertFalse(str.isEmpty)
        let decoded = try JSONDecoder().decode(
            JSONSchema.self,
            from: try XCTUnwrap(str.data(using: .utf8))
        )
        XCTAssertEqual(decoded, schema)
    }

    // MARK: - Equatable

    func test_equatable() {
        XCTAssertEqual(JSONSchema.string(), JSONSchema.string())
        XCTAssertNotEqual(JSONSchema.string(), JSONSchema.number())
        XCTAssertEqual(JSONSchema.anyOf([.string(), .null()]), JSONSchema.anyOf([.string(), .null()]))
    }

    // MARK: - SchemaType CaseIterable

    func test_all_schema_types() {
        XCTAssertEqual(JSONSchema.SchemaType.allCases.count, 7)
    }
}
