//
//  JSONCoercionTests.swift
//  JSONTests
//

import XCTest
@testable import JSON

final class JSONCoercionTests: XCTestCase {

    // MARK: - Null + default

    func test_null_replaced_by_schema_default() {
        let schema = JSONSchema(type: .string, default: .string("unknown"))
        let result = JSON.null.coerced(to: schema)
        XCTAssertEqual(result.value, .string("unknown"))
        XCTAssertFalse(result.isUnchanged)
        XCTAssertTrue(result.changes.contains { $0.contains("default") })
    }

    func test_non_null_value_not_replaced_by_default() {
        let schema = JSONSchema(type: .string, default: .string("fallback"))
        let result = JSON.string("actual").coerced(to: schema)
        XCTAssertEqual(result.value, .string("actual"))
        XCTAssertTrue(result.isUnchanged)
    }

    // MARK: - String → number

    func test_string_to_number_coercion() {
        let schema = JSONSchema.number()
        let result = JSON.string("3.14").coerced(to: schema)
        XCTAssertEqual(result.value, .number(3.14))
        XCTAssertFalse(result.isUnchanged)
    }

    func test_string_to_integer_coercion() {
        let schema = JSONSchema.integer()
        let result = JSON.string("42").coerced(to: schema)
        XCTAssertEqual(result.value, .number(42))
        XCTAssertFalse(result.isUnchanged)
    }

    func test_non_numeric_string_not_coerced_to_number() {
        let schema = JSONSchema.number()
        let result = JSON.string("hello").coerced(to: schema)
        XCTAssertEqual(result.value, .string("hello"))  // unchanged — can't coerce
        XCTAssertTrue(result.isUnchanged)
    }

    // MARK: - Number → string

    func test_number_to_string_coercion_integer() {
        let schema = JSONSchema.string()
        let result = JSON.number(42).coerced(to: schema)
        XCTAssertEqual(result.value, .string("42"))
        XCTAssertFalse(result.isUnchanged)
    }

    func test_number_to_string_coercion_float() {
        let schema = JSONSchema.string()
        let result = JSON.number(3.14).coerced(to: schema)
        XCTAssertEqual(result.value, .string("3.14"))
        XCTAssertFalse(result.isUnchanged)
    }

    // MARK: - String → boolean

    func test_string_true_to_boolean() {
        let schema = JSONSchema.boolean()
        for s in ["true", "yes", "1"] {
            let r = JSON.string(s).coerced(to: schema)
            XCTAssertEqual(r.value, .bool(true), "Expected true for '\(s)'")
        }
    }

    func test_string_false_to_boolean() {
        let schema = JSONSchema.boolean()
        for s in ["false", "no", "0"] {
            let r = JSON.string(s).coerced(to: schema)
            XCTAssertEqual(r.value, .bool(false), "Expected false for '\(s)'")
        }
    }

    // MARK: - Additional properties removed

    func test_additional_properties_removed_when_restricted() {
        let schema = JSONSchema.object(
            properties: ["name": .string()],
            required: ["name"],
            additionalProperties: .bool(false)
        )
        let input: JSON = ["name": "Alice", "extra": "should be removed"]
        let result = input.coerced(to: schema)
        XCTAssertEqual(result.value["name"], .string("Alice"))
        XCTAssertNil(result.value["extra"])
        XCTAssertTrue(result.changes.contains { $0.contains("extra") })
    }

    func test_additional_properties_kept_when_allowed() {
        let schema = JSONSchema.object(
            properties: ["name": .string()],
            additionalProperties: .bool(true)
        )
        let input: JSON = ["name": "Alice", "extra": "stays"]
        let result = input.coerced(to: schema)
        XCTAssertEqual(result.value["extra"], .string("stays"))
    }

    // MARK: - Property defaults applied

    func test_missing_property_gets_default() {
        let schema = JSONSchema.object(properties: [
            "name": .string(),
            "role": JSONSchema(type: .string, default: .string("user")),
        ])
        let input: JSON = ["name": "Bob"]
        let result = input.coerced(to: schema)
        XCTAssertEqual(result.value["role"], .string("user"))
        XCTAssertTrue(result.changes.contains { $0.contains("role") && $0.contains("default") })
    }

    // MARK: - Recursive coercion

    func test_recursive_coercion_in_nested_object() {
        let schema = JSONSchema.object(properties: [
            "count": .number(),
        ])
        let input: JSON = ["count": "7"]
        let result = input.coerced(to: schema)
        XCTAssertEqual(result.value["count"], .number(7))
    }

    func test_recursive_coercion_in_array_items() {
        let schema = JSONSchema.array(items: .number())
        let input: JSON = ["1", "2", "3"]
        let result = input.coerced(to: schema)
        XCTAssertEqual(result.value, .array([.number(1), .number(2), .number(3)]))
    }

    // MARK: - anyOf branch selection

    func test_anyof_uses_first_valid_branch() {
        let schema = JSONSchema.anyOf([.number(), .string()])
        // Already a number — first branch matches immediately.
        let r = JSON.number(5).coerced(to: schema)
        XCTAssertEqual(r.value, .number(5))
    }

    func test_anyof_coerces_to_valid_branch() {
        // "42" can be coerced to number — first branch
        let schema = JSONSchema.anyOf([.number(), .boolean()])
        let r = JSON.string("42").coerced(to: schema)
        XCTAssertEqual(r.value, .number(42))
    }

    // MARK: - No-op (already valid)

    func test_already_valid_value_is_unchanged() {
        let schema = JSONSchema.object(properties: [
            "name": .string(),
            "age":  .integer(),
        ], required: ["name", "age"], additionalProperties: .bool(false))
        let input: JSON = ["name": "Alice", "age": 30]
        let result = input.coerced(to: schema)
        XCTAssertEqual(result.value, input)
        XCTAssertTrue(result.isUnchanged)
    }

    // MARK: - CoercionResult API

    func test_coercion_result_changes_list() {
        let schema = JSONSchema.number()
        let result = JSON.string("99").coerced(to: schema)
        XCTAssertFalse(result.changes.isEmpty)
        XCTAssertFalse(result.isUnchanged)
        XCTAssertEqual(result.value, .number(99))
    }
}
