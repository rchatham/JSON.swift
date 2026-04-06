//
//  JSONValidationTests.swift
//  JSONTests
//
//  Created by Reid Chatham on 4/6/25.
//

import XCTest
@testable import JSON

final class JSONValidationTests: XCTestCase {

    // MARK: - Primitive type checks

    func test_string_valid() {
        XCTAssertTrue(JSON.string("hello").isValid(against: .string()))
    }

    func test_string_wrong_type() {
        XCTAssertFalse(JSON.number(1).isValid(against: .string()))
    }

    func test_number_valid() {
        XCTAssertTrue(JSON.number(3.14).isValid(against: .number()))
    }

    func test_integer_schema_accepts_whole_double() {
        // 3.0 is a valid integer value even though it's stored as Double
        XCTAssertTrue(JSON.number(3.0).isValid(against: .integer()))
    }

    func test_integer_schema_rejects_fractional() {
        XCTAssertFalse(JSON.number(3.14).isValid(against: .integer()))
    }

    func test_boolean_valid() {
        XCTAssertTrue(JSON.bool(true).isValid(against: .boolean()))
    }

    func test_null_valid() {
        XCTAssertTrue(JSON.null.isValid(against: .null()))
    }

    func test_null_wrong_type() {
        XCTAssertFalse(JSON.null.isValid(against: .string()))
    }

    // MARK: - enum constraint

    func test_enum_valid() {
        let schema = JSONSchema.string(enumValues: ["red", "green", "blue"])
        XCTAssertTrue(JSON.string("red").isValid(against: schema))
    }

    func test_enum_invalid() {
        let schema = JSONSchema.string(enumValues: ["red", "green", "blue"])
        let result = JSON.string("purple").validationResult(against: schema)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertTrue(result.errors[0].reason.contains("purple"))
    }

    // MARK: - object: required

    func test_object_all_required_present() {
        let schema = JSONSchema.object(
            properties: ["name": .string(), "age": .integer()],
            required: ["name", "age"]
        )
        let json: JSON = ["name": "Alice", "age": 30]
        XCTAssertTrue(json.isValid(against: schema))
    }

    func test_object_missing_required_property() {
        let schema = JSONSchema.object(
            properties: ["name": .string(), "age": .integer()],
            required: ["name", "age"]
        )
        let json: JSON = ["name": "Alice"]
        let result = json.validationResult(against: schema)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.reason.contains("age") })
    }

    func test_object_multiple_missing_required_all_reported() {
        let schema = JSONSchema.object(
            properties: ["a": .string(), "b": .string(), "c": .string()],
            required: ["a", "b", "c"]
        )
        let json: JSON = .object([:])
        let result = json.validationResult(against: schema)
        XCTAssertEqual(result.errors.count, 3)
    }

    // MARK: - object: additionalProperties

    func test_object_no_additional_properties_passes() {
        let schema = JSONSchema.object(
            properties: ["x": .number()],
            additionalProperties: false
        )
        let json: JSON = ["x": 1]
        XCTAssertTrue(json.isValid(against: schema))
    }

    func test_object_additional_property_rejected() {
        let schema = JSONSchema.object(
            properties: ["x": .number()],
            additionalProperties: false
        )
        let json: JSON = ["x": 1, "extra": "bad"]
        let result = json.validationResult(against: schema)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.reason.contains("extra") })
    }

    // MARK: - object: nested property type checking

    func test_object_property_wrong_type() {
        let schema = JSONSchema.object(
            properties: ["age": .integer()],
            required: ["age"]
        )
        // age is a string, not a number
        let json: JSON = ["age": "thirty"]
        let result = json.validationResult(against: schema)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.path == "root.age" })
    }

    func test_object_nested_object_validates_recursively() {
        let schema = JSONSchema.object(
            properties: [
                "address": .object(
                    properties: ["city": .string(), "zip": .string()],
                    required: ["city", "zip"],
                    additionalProperties: true   // allow extra keys in nested object
                )
            ],
            required: ["address"],
            additionalProperties: true           // allow extra keys at top level
        )
        let valid: JSON = ["address": ["city": "Portland", "zip": "97201"]]
        XCTAssertTrue(valid.isValid(against: schema))

        let invalid: JSON = ["address": ["city": "Portland"]] // missing zip
        let result = invalid.validationResult(against: schema)
        XCTAssertFalse(result.isValid)
        // Missing-required errors are reported at the parent path with the key name in the reason.
        XCTAssertTrue(result.errors.contains { $0.reason.contains("zip") })
    }

    // MARK: - array item validation

    func test_array_items_all_valid() {
        let schema = JSONSchema.array(items: .string())
        let json: JSON = ["a", "b", "c"]
        XCTAssertTrue(json.isValid(against: schema))
    }

    func test_array_items_wrong_type_reports_index_path() {
        let schema = JSONSchema.array(items: .string())
        let json: JSON = ["a", 2, "c"]
        let result = json.validationResult(against: schema)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.path == "root[1]" })
    }

    func test_array_empty_always_valid() {
        let schema = JSONSchema.array(items: .string())
        XCTAssertTrue(JSON.array([]).isValid(against: schema))
    }

    // MARK: - anyOf

    func test_anyOf_matches_first() {
        let schema = JSONSchema.anyOf([.string(), .null()])
        XCTAssertTrue(JSON.string("hi").isValid(against: schema))
    }

    func test_anyOf_matches_second() {
        let schema = JSONSchema.anyOf([.string(), .null()])
        XCTAssertTrue(JSON.null.isValid(against: schema))
    }

    func test_anyOf_matches_none() {
        let schema = JSONSchema.anyOf([.string(), .null()])
        let result = JSON.number(42).validationResult(against: schema)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors[0].reason.contains("anyOf"))
    }

    func test_nullable_convenience() {
        let schema = JSONSchema.integer().nullable
        XCTAssertTrue(JSON.number(1).isValid(against: schema))
        XCTAssertTrue(JSON.null.isValid(against: schema))
        XCTAssertFalse(JSON.string("x").isValid(against: schema))
    }

    // MARK: - oneOf

    func test_oneOf_exactly_one_match() {
        let schema = JSONSchema.oneOf([.string(), .number()])
        XCTAssertTrue(JSON.string("x").isValid(against: schema))
    }

    func test_oneOf_no_match() {
        let schema = JSONSchema.oneOf([.string(), .number()])
        XCTAssertFalse(JSON.bool(true).isValid(against: schema))
    }

    // MARK: - allOf

    func test_allOf_all_pass() {
        // Both sub-schemas are partial object constraints (additionalProperties: true
        // so each only enforces its own required key, not the other's).
        let schema = JSONSchema.allOf([
            .object(properties: ["a": .string()], required: ["a"], additionalProperties: true),
            .object(properties: ["b": .number()], required: ["b"], additionalProperties: true),
        ])
        let json: JSON = ["a": "hello", "b": 1]
        XCTAssertTrue(json.isValid(against: schema))
    }

    func test_allOf_one_fails() {
        let schema = JSONSchema.allOf([
            .object(properties: ["a": .string()], required: ["a"], additionalProperties: true),
            .object(properties: ["b": .number()], required: ["b"], additionalProperties: true),
        ])
        let json: JSON = ["a": "hello"] // missing b
        XCTAssertFalse(json.isValid(against: schema))
    }

    // MARK: - throwing validate

    func test_validate_throws_on_failure() {
        let schema = JSONSchema.string()
        XCTAssertThrowsError(try JSON.number(1).validate(against: schema)) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }

    func test_validate_does_not_throw_on_success() {
        XCTAssertNoThrow(try JSON.string("ok").validate(against: .string()))
    }

    func test_schema_validate_method() throws {
        let schema = JSONSchema.object(
            properties: ["id": .integer()],
            required: ["id"]
        )
        let json: JSON = ["id": 42]
        XCTAssertNoThrow(try schema.validate(json))
    }

    // MARK: - path reporting

    func test_error_path_is_root_for_top_level() {
        let result = JSON.number(1).validationResult(against: .string())
        XCTAssertEqual(result.errors.first?.path, "root")
    }

    func test_error_path_includes_key() {
        let schema = JSONSchema.object(properties: ["x": .string()])
        let json: JSON = ["x": 99]
        let result = json.validationResult(against: schema)
        XCTAssertEqual(result.errors.first?.path, "root.x")
    }

    func test_error_path_includes_array_index() {
        let schema = JSONSchema.array(items: .boolean())
        let json: JSON = [true, false, "oops"]
        let result = json.validationResult(against: schema)
        XCTAssertEqual(result.errors.first?.path, "root[2]")
    }

    // MARK: - JSONConvertible integration

    func test_validate_against_json_convertible_schema() throws {
        struct Person: JSONConvertible {
            let name: String
            let age: Int
            static var jsonSchema: JSONSchema {
                .object(
                    properties: ["name": .string(), "age": .integer()],
                    required: ["name", "age"],
                    additionalProperties: false
                )
            }
        }

        let valid: JSON = ["name": "Alice", "age": 30]
        XCTAssertTrue(valid.isValid(against: Person.jsonSchema))

        let invalid: JSON = ["name": "Alice"] // missing age
        XCTAssertFalse(invalid.isValid(against: Person.jsonSchema))
    }

    // MARK: - Inferred schema

    func test_infer_string() {
        XCTAssertEqual(JSON.string("hi").inferredSchema().type, .string)
    }

    func test_infer_number_fractional() {
        XCTAssertEqual(JSON.number(3.14).inferredSchema().type, .number)
    }

    func test_infer_integer_whole() {
        XCTAssertEqual(JSON.number(7.0).inferredSchema().type, .integer)
    }

    func test_infer_bool() {
        XCTAssertEqual(JSON.bool(true).inferredSchema().type, .boolean)
    }

    func test_infer_null() {
        XCTAssertEqual(JSON.null.inferredSchema().type, .null)
    }

    func test_infer_array_of_strings() {
        let schema = JSON.array([.string("a"), .string("b")]).inferredSchema()
        XCTAssertEqual(schema.type, .array)
        XCTAssertEqual(schema.items?.type, .string)
    }

    func test_infer_empty_array() {
        let schema = JSON.array([]).inferredSchema()
        XCTAssertEqual(schema.type, .array)
    }

    func test_infer_object_properties_and_required() {
        let json: JSON = ["name": "Alice", "age": 30]
        let schema = json.inferredSchema()
        XCTAssertEqual(schema.type, .object)
        XCTAssertEqual(schema.properties?["name"]?.type, .string)
        XCTAssertEqual(schema.properties?["age"]?.type, .integer)
        // All keys present → all required
        XCTAssertTrue(schema.required?.contains("name") == true)
        XCTAssertTrue(schema.required?.contains("age") == true)
    }

    func test_inferred_schema_validates_source_value() {
        let json: JSON = ["status": "active", "score": 9.5]
        let schema = json.inferredSchema()
        // The value that produced the schema must itself pass validation.
        XCTAssertTrue(json.isValid(against: schema))
    }

    func test_inferred_schema_rejects_structurally_different_value() {
        let json: JSON = ["name": "Alice", "age": 30]
        let schema = json.inferredSchema()
        // Object with wrong type for "age"
        let bad: JSON = ["name": "Bob", "age": "thirty"]
        XCTAssertFalse(bad.isValid(against: schema))
    }

    func test_json_schema_infer_static_method() {
        let json: JSON = ["x": 1]
        let schema = JSONSchema.infer(from: json)
        XCTAssertEqual(schema.type, .object)
    }

    func test_mixed_array_produces_anyOf_items() {
        let json: JSON = [1, "hello"]
        let schema = json.inferredSchema()
        XCTAssertEqual(schema.type, .array)
        // Items are mixed type → anyOf
        XCTAssertNotNil(schema.items?.anyOf)
    }
}
