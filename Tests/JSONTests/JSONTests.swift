//
//  JSONTests.swift
//  JSONTests
//
//  Created by Reid Chatham on 4/5/25.
//

import XCTest
@testable import JSON

final class JSONTests: XCTestCase {

    // MARK: - Decoding

    func test_decode_string() throws {
        let json = try JSON(string: "\"hello\"")
        XCTAssertEqual(json, .string("hello"))
    }

    func test_decode_number_integer() throws {
        let json = try JSON(string: "42")
        XCTAssertEqual(json, .number(42))
    }

    func test_decode_number_float() throws {
        let json = try JSON(string: "3.14")
        XCTAssertEqual(json, .number(3.14))
    }

    func test_decode_bool_true() throws {
        let json = try JSON(string: "true")
        XCTAssertEqual(json, .bool(true))
    }

    func test_decode_bool_false() throws {
        let json = try JSON(string: "false")
        XCTAssertEqual(json, .bool(false))
    }

    func test_decode_null() throws {
        let json = try JSON(string: "null")
        XCTAssertEqual(json, .null)
    }

    func test_decode_array() throws {
        let json = try JSON(string: "[1, \"two\", true, null]")
        XCTAssertEqual(json, .array([.number(1), .string("two"), .bool(true), .null]))
    }

    func test_decode_object() throws {
        let json = try JSON(string: #"{"name":"Alice","age":30}"#)
        XCTAssertEqual(json["name"], .string("Alice"))
        XCTAssertEqual(json["age"], .number(30))
    }

    func test_decode_nested_object() throws {
        let src = #"{"user":{"name":"Bob","scores":[10,20]}}"#
        let json = try JSON(string: src)
        XCTAssertEqual(json["user"]?["name"], .string("Bob"))
        XCTAssertEqual(json["user"]?["scores"]?[0], .number(10))
        XCTAssertEqual(json["user"]?["scores"]?[1], .number(20))
    }

    func test_decode_bool_not_confused_with_number() throws {
        let json = try JSON(string: "true")
        XCTAssertEqual(json, .bool(true))
        XCTAssertNil(json.doubleValue)
    }

    func test_decode_invalid_json_throws() {
        XCTAssertThrowsError(try JSON(string: "not json"))
    }

    // MARK: - Encoding

    func test_encode_string() throws {
        let json = JSON.string("hello")
        let roundtrip = try JSON(data: JSONEncoder().encode(json))
        XCTAssertEqual(roundtrip, json)
    }

    func test_encode_number() throws {
        let json = JSON.number(99.5)
        let roundtrip = try JSON(data: JSONEncoder().encode(json))
        XCTAssertEqual(roundtrip, json)
    }

    func test_encode_bool() throws {
        let json = JSON.bool(false)
        let roundtrip = try JSON(data: JSONEncoder().encode(json))
        XCTAssertEqual(roundtrip, json)
    }

    func test_encode_null() throws {
        let json = JSON.null
        let roundtrip = try JSON(data: JSONEncoder().encode(json))
        XCTAssertEqual(roundtrip, json)
    }

    func test_encode_object_roundtrip() throws {
        let json: JSON = .object(["key": .string("value"), "num": .number(1)])
        let roundtrip = try JSON(data: JSONEncoder().encode(json))
        XCTAssertEqual(roundtrip, json)
    }

    func test_encode_array_roundtrip() throws {
        let json: JSON = .array([.string("a"), .number(1), .bool(true), .null])
        let roundtrip = try JSON(data: JSONEncoder().encode(json))
        XCTAssertEqual(roundtrip, json)
    }

    // MARK: - Value Extraction

    func test_stringValue() {
        XCTAssertEqual(JSON.string("hi").stringValue, "hi")
        XCTAssertNil(JSON.number(1).stringValue)
    }

    func test_doubleValue() {
        XCTAssertEqual(JSON.number(3.5).doubleValue, 3.5)
        XCTAssertNil(JSON.string("x").doubleValue)
    }

    func test_intValue_exact() {
        XCTAssertEqual(JSON.number(7).intValue, 7)
        XCTAssertNil(JSON.bool(true).intValue)
    }

    func test_intValue_returns_nil_for_fractional() {
        // intValue is now exact-only; fractional numbers return nil.
        XCTAssertNil(JSON.number(7.9).intValue)
    }

    func test_truncatedIntValue() {
        XCTAssertEqual(JSON.number(7.9).truncatedIntValue, 7)
        XCTAssertEqual(JSON.number(7.0).truncatedIntValue, 7)
        XCTAssertNil(JSON.string("x").truncatedIntValue)
    }

    func test_boolValue() {
        XCTAssertEqual(JSON.bool(true).boolValue, true)
        XCTAssertNil(JSON.number(1).boolValue)
    }

    func test_arrayValue() {
        XCTAssertEqual(JSON.array([.null]).arrayValue, [.null])
        XCTAssertNil(JSON.object([:]).arrayValue)
    }

    func test_objectValue() {
        XCTAssertEqual(JSON.object(["k": .null]).objectValue, ["k": .null])
        XCTAssertNil(JSON.array([]).objectValue)
    }

    func test_isNull() {
        XCTAssertTrue(JSON.null.isNull)
        XCTAssertFalse(JSON.bool(false).isNull)
    }

    // MARK: - Subscript (read)

    func test_subscript_string_key_hit() {
        let json: JSON = .object(["a": .number(1)])
        XCTAssertEqual(json["a"], .number(1))
    }

    func test_subscript_string_key_miss() {
        let json: JSON = .object(["a": .number(1)])
        XCTAssertNil(json["z"])
    }

    func test_subscript_string_key_on_non_object() {
        XCTAssertNil(JSON.array([.null])["key"])
    }

    func test_subscript_int_index() {
        let json: JSON = .array([.string("x"), .number(2)])
        XCTAssertEqual(json[0], .string("x"))
        XCTAssertEqual(json[1], .number(2))
    }

    func test_subscript_int_out_of_bounds() {
        let json: JSON = .array([.string("x")])
        XCTAssertNil(json[5])
        XCTAssertNil(json[-1])
    }

    func test_subscript_int_on_non_array() {
        let json: JSON = .object([:])
        XCTAssertNil(json[0])
    }

    // MARK: - Subscript (write / mutating)

    func test_subscript_string_set_new_key() {
        var json: JSON = .object(["a": .number(1)])
        json["b"] = .string("hello")
        XCTAssertEqual(json["b"], .string("hello"))
        XCTAssertEqual(json["a"], .number(1)) // unchanged
    }

    func test_subscript_string_overwrite_key() {
        var json: JSON = .object(["a": .number(1)])
        json["a"] = .bool(true)
        XCTAssertEqual(json["a"], .bool(true))
    }

    func test_subscript_string_remove_key() {
        var json: JSON = .object(["a": .number(1)])
        json["a"] = nil
        XCTAssertNil(json["a"])
    }

    func test_subscript_int_overwrite_element() {
        var json: JSON = .array([.number(0), .number(1)])
        json[0] = .string("replaced")
        XCTAssertEqual(json[0], .string("replaced"))
        XCTAssertEqual(json[1], .number(1))
    }

    func test_subscript_int_write_out_of_bounds_noop() {
        var json: JSON = .array([.number(0)])
        json[5] = .string("noop")
        // Should be unchanged — out-of-bounds write is silently ignored
        XCTAssertEqual(json.arrayValue?.count, 1)
    }

    // MARK: - @dynamicMemberLookup

    func test_dynamic_member_lookup_read() {
        let json: JSON = .object(["name": .string("Alice")])
        XCTAssertEqual(json.name, .string("Alice"))
    }

    func test_dynamic_member_lookup_read_missing() {
        let json: JSON = .object(["name": .string("Alice")])
        XCTAssertNil(json.missing)
    }

    func test_dynamic_member_lookup_write() {
        var json: JSON = .object(["name": .string("Alice")])
        json.name = .string("Bob")
        XCTAssertEqual(json.name, .string("Bob"))
    }

    // MARK: - Throwing access (value(forKey:) / value(at:))

    func test_value_forKey_hit() throws {
        let json: JSON = .object(["x": .number(1)])
        let v = try json.value(forKey: "x")
        XCTAssertEqual(v, .number(1))
    }

    func test_value_forKey_missing_throws() {
        let json: JSON = .object(["x": .number(1)])
        XCTAssertThrowsError(try json.value(forKey: "missing")) { error in
            if case JSONError.keyNotFound(let key) = error {
                XCTAssertEqual(key, "missing")
            } else {
                XCTFail("Expected JSONError.keyNotFound, got \(error)")
            }
        }
    }

    func test_value_forKey_on_non_object_throws() {
        let json: JSON = .array([.null])
        XCTAssertThrowsError(try json.value(forKey: "key")) { error in
            if case JSONError.typeMismatch = error { return }
            XCTFail("Expected JSONError.typeMismatch, got \(error)")
        }
    }

    func test_value_at_index_hit() throws {
        let json: JSON = .array([.string("a"), .string("b")])
        let v = try json.value(at: 1)
        XCTAssertEqual(v, .string("b"))
    }

    func test_value_at_index_out_of_bounds_throws() {
        let json: JSON = .array([.null])
        XCTAssertThrowsError(try json.value(at: 99)) { error in
            if case JSONError.indexOutOfBounds(let idx) = error {
                XCTAssertEqual(idx, 99)
            } else {
                XCTFail("Expected JSONError.indexOutOfBounds, got \(error)")
            }
        }
    }

    func test_value_at_on_non_array_throws() {
        let json: JSON = .object(["k": .null])
        XCTAssertThrowsError(try json.value(at: 0)) { error in
            if case JSONError.typeMismatch = error { return }
            XCTFail("Expected JSONError.typeMismatch, got \(error)")
        }
    }

    // MARK: - Literals

    func test_string_literal() {
        let json: JSON = "hello"
        XCTAssertEqual(json, .string("hello"))
    }

    func test_integer_literal() {
        let json: JSON = 42
        XCTAssertEqual(json, .number(42))
    }

    func test_float_literal() {
        let json: JSON = 3.14
        XCTAssertEqual(json, .number(3.14))
    }

    func test_bool_literal() {
        let json: JSON = true
        XCTAssertEqual(json, .bool(true))
    }

    func test_nil_literal() {
        let json: JSON = nil
        XCTAssertEqual(json, .null)
    }

    func test_array_literal() {
        let json: JSON = [1, "two", true]
        XCTAssertEqual(json, .array([.number(1), .string("two"), .bool(true)]))
    }

    func test_dictionary_literal() {
        let json: JSON = ["key": "value"]
        XCTAssertEqual(json, .object(["key": .string("value")]))
    }

    // MARK: - Any bridge

    func test_init_from_any_string() throws {
        XCTAssertEqual(try JSON("hello"), .string("hello"))
    }

    func test_init_from_any_int() throws {
        XCTAssertEqual(try JSON(42), .number(42))
    }

    func test_init_from_any_double() throws {
        XCTAssertEqual(try JSON(3.14), .number(3.14))
    }

    func test_init_from_any_bool() throws {
        XCTAssertEqual(try JSON(true), .bool(true))
    }

    func test_init_from_any_nsNull() throws {
        XCTAssertEqual(try JSON(NSNull()), .null)
    }

    func test_init_from_any_array() throws {
        let json = try JSON(["a", 1, true] as [Any])
        XCTAssertEqual(json, .array([.string("a"), .number(1), .bool(true)]))
    }

    func test_init_from_any_dict() throws {
        let json = try JSON(["k": "v"] as [String: Any])
        XCTAssertEqual(json, .object(["k": .string("v")]))
    }

    func test_init_from_any_unsupported_throws() {
        struct Foo {}
        XCTAssertThrowsError(try JSON(Foo()))
    }

    // MARK: - jsonString / Dictionary.jsonString consistency

    func test_jsonString_is_valid_json() throws {
        let json: JSON = .object(["a": .number(1), "b": .bool(false)])
        let string = try XCTUnwrap(json.jsonString)
        let decoded = try JSON(string: string)
        XCTAssertEqual(decoded, json)
    }

    func test_dictionary_jsonString_matches_json_jsonString() {
        let dict: [String: JSON] = ["x": .number(1), "flag": .bool(true)]
        let json = JSON.object(dict)
        XCTAssertEqual(dict.jsonString, json.jsonString)
    }

    // MARK: - Equatable

    func test_equatable_same() {
        XCTAssertEqual(JSON.string("x"), JSON.string("x"))
        XCTAssertEqual(JSON.number(1.0), JSON.number(1.0))
        XCTAssertEqual(JSON.bool(false), JSON.bool(false))
        XCTAssertEqual(JSON.null, JSON.null)
        XCTAssertEqual(JSON.array([.null]), JSON.array([.null]))
        XCTAssertEqual(JSON.object(["k": .null]), JSON.object(["k": .null]))
    }

    func test_equatable_different_cases() {
        XCTAssertNotEqual(JSON.string("x"), JSON.number(1))
        XCTAssertNotEqual(JSON.bool(true), JSON.null)
    }

    // MARK: - Hashable

    func test_hashable_in_set() {
        var set: Set<JSON> = []
        set.insert(.string("a"))
        set.insert(.string("a"))
        set.insert(.number(1))
        XCTAssertEqual(set.count, 2)
    }

    func test_hashable_as_dict_key() {
        var dict: [JSON: String] = [:]
        dict[.string("k")] = "v"
        XCTAssertEqual(dict[.string("k")], "v")
    }

    // MARK: - B1 regression: Bool in init(_ value: Any)

    func test_init_from_any_bool_is_bool_not_number() throws {
        // On Apple platforms, `true as Double` = 1.0. Bool MUST be matched before Double.
        let trueJSON  = try JSON(true as Any)
        let falseJSON = try JSON(false as Any)
        XCTAssertEqual(trueJSON,  .bool(true),  "true should be .bool(true), not .number(1.0)")
        XCTAssertEqual(falseJSON, .bool(false), "false should be .bool(false), not .number(0.0)")
        XCTAssertNil(trueJSON.doubleValue)
        XCTAssertNil(falseJSON.doubleValue)
    }

    func test_init_from_any_float() throws {
        let json = try JSON(Float(2.5))
        XCTAssertEqual(json, .number(Double(Float(2.5))))
    }

    func test_init_from_any_int32() throws {
        XCTAssertEqual(try JSON(Int32(7)), .number(7))
    }

    func test_init_from_any_int64() throws {
        XCTAssertEqual(try JSON(Int64(100)), .number(100))
    }

    func test_init_from_any_nested_array_of_dicts() throws {
        let input: [Any] = [["x": 1], ["x": 2]] as [Any]
        let json = try JSON(input)
        XCTAssertEqual(json[0]?["x"], .number(1))
        XCTAssertEqual(json[1]?["x"], .number(2))
    }

    // MARK: - F1: JSON(encoding:)

    func test_init_encoding_codable_struct() throws {
        struct Point: Encodable { let x: Double; let y: Double }
        let json = try JSON(encoding: Point(x: 1.5, y: 2.5))
        XCTAssertEqual(json["x"], .number(1.5))
        XCTAssertEqual(json["y"], .number(2.5))
    }

    func test_init_encoding_array() throws {
        let json = try JSON(encoding: [1, 2, 3])
        XCTAssertEqual(json, .array([.number(1), .number(2), .number(3)]))
    }

    func test_init_encoding_string() throws {
        let json = try JSON(encoding: "hello")
        XCTAssertEqual(json, .string("hello"))
    }

    // MARK: - F2: jsonData

    func test_jsonData_produces_decodable_data() throws {
        let json: JSON = ["name": "Alice", "score": 99]
        let data = try XCTUnwrap(json.jsonData)
        let roundtrip = try JSON(data: data)
        XCTAssertEqual(roundtrip, json)
    }

    func test_jsonData_is_consistent_with_jsonString() throws {
        let json: JSON = .array([1, 2, 3])
        let fromData   = try XCTUnwrap(json.jsonData).flatMap { String(data: $0, encoding: .utf8) }
        let fromString = json.jsonString
        XCTAssertEqual(fromData, fromString)
    }

    // MARK: - E1: jsonString(formatting:)

    func test_jsonString_compact_has_no_whitespace_around_braces() throws {
        let json: JSON = ["a": 1]
        let compact = try XCTUnwrap(json.jsonString(formatting: []))
        // Compact output should not contain newlines.
        XCTAssertFalse(compact.contains("\n"))
    }

    func test_jsonString_pretty_contains_newline() throws {
        let json: JSON = ["a": 1]
        let pretty = try XCTUnwrap(json.jsonString(formatting: .prettyPrinted))
        XCTAssertTrue(pretty.contains("\n"))
    }

    func test_jsonString_default_is_pretty_sorted() throws {
        let json: JSON = ["b": 2, "a": 1]
        let s = try XCTUnwrap(json.jsonString)
        // Sorted keys: "a" should appear before "b"
        let aIdx = try XCTUnwrap(s.range(of: "\"a\"")).lowerBound
        let bIdx = try XCTUnwrap(s.range(of: "\"b\"")).lowerBound
        XCTAssertLessThan(aIdx, bIdx)
    }

    // MARK: - F3: json[keyPath:]

    func test_keypath_subscript_single_level() {
        let json: JSON = ["name": "Alice"]
        XCTAssertEqual(json[keyPath: "name"], .string("Alice"))
    }

    func test_keypath_subscript_two_levels() {
        let json: JSON = ["user": ["age": 30]]
        XCTAssertEqual(json[keyPath: "user.age"], .number(30))
    }

    func test_keypath_subscript_three_levels() {
        let json: JSON = ["a": ["b": ["c": "deep"]]]
        XCTAssertEqual(json[keyPath: "a.b.c"], .string("deep"))
    }

    func test_keypath_subscript_missing_returns_nil() {
        let json: JSON = ["x": 1]
        XCTAssertNil(json[keyPath: "x.missing"])
        XCTAssertNil(json[keyPath: "missing"])
    }

    func test_keypath_subscript_write_creates_nested_structure() {
        var json: JSON = .object([:])
        json[keyPath: "user.name"] = .string("Bob")
        XCTAssertEqual(json[keyPath: "user.name"], .string("Bob"))
    }

    func test_keypath_subscript_write_overwrites_existing() {
        var json: JSON = ["user": ["name": "Alice"]]
        json[keyPath: "user.name"] = .string("Bob")
        XCTAssertEqual(json[keyPath: "user.name"], .string("Bob"))
    }

    func test_keypath_subscript_write_nil_removes_key() {
        var json: JSON = ["user": ["name": "Alice"]]
        json[keyPath: "user.name"] = nil
        XCTAssertNil(json[keyPath: "user.name"])
    }

    // MARK: - F4: Sequence conformance

    func test_sequence_iterates_array_elements() {
        let json: JSON = [1, 2, 3]
        var results: [JSON] = []
        for item in json { results.append(item) }
        XCTAssertEqual(results, [.number(1), .number(2), .number(3)])
    }

    func test_sequence_on_non_array_is_empty() {
        let json: JSON = .object(["x": .null])
        XCTAssertEqual(Array(json), [])
    }

    func test_sequence_empty_array() {
        let json: JSON = .array([])
        XCTAssertEqual(Array(json), [])
    }

    // MARK: - F5: merging

    func test_merging_combines_keys() {
        let base: JSON  = ["a": 1, "b": 2]
        let patch: JSON = ["b": 99, "c": 3]
        let merged = base.merging(patch)
        XCTAssertEqual(merged["a"], .number(1))
        XCTAssertEqual(merged["b"], .number(99))   // patch wins
        XCTAssertEqual(merged["c"], .number(3))
    }

    func test_merging_with_non_object_returns_self() {
        let json: JSON = .array([1])
        XCTAssertEqual(json.merging(.object(["x": .null])), json)
    }

    func test_merge_mutates_in_place() {
        var json: JSON = ["x": 1]
        json.merge(["y": 2])
        XCTAssertEqual(json["x"], .number(1))
        XCTAssertEqual(json["y"], .number(2))
    }

    // MARK: - jsonCompatible

    func test_jsonCompatible_string() {
        XCTAssertEqual(JSON.string("hi").jsonCompatible as? String, "hi")
    }

    func test_jsonCompatible_number() {
        XCTAssertEqual(JSON.number(3.14).jsonCompatible as? Double, 3.14)
    }

    func test_jsonCompatible_bool() {
        XCTAssertEqual(JSON.bool(true).jsonCompatible as? Bool, true)
    }

    func test_jsonCompatible_null() {
        XCTAssertTrue(JSON.null.jsonCompatible is NSNull)
    }

    func test_jsonCompatible_array() {
        let compat = JSON.array([.number(1), .string("x")]).jsonCompatible
        guard let arr = compat as? [Any] else { return XCTFail("Expected [Any]") }
        XCTAssertEqual(arr[0] as? Double, 1.0)
        XCTAssertEqual(arr[1] as? String, "x")
    }

    func test_jsonCompatible_object() {
        let compat = JSON.object(["k": .bool(false)]).jsonCompatible
        guard let dict = compat as? [String: Any] else { return XCTFail("Expected [String:Any]") }
        XCTAssertEqual(dict["k"] as? Bool, false)
    }

    // MARK: - CustomStringConvertible / CustomDebugStringConvertible

    func test_description_is_json_string() throws {
        let json: JSON = ["x": 1]
        let desc = json.description
        XCTAssertTrue(desc.contains("\"x\""))
    }

    func test_debugDescription_string() {
        XCTAssertEqual(JSON.string("hi").debugDescription, #"JSON.string("hi")"#)
    }

    func test_debugDescription_number() {
        XCTAssertEqual(JSON.number(3.14).debugDescription, "JSON.number(3.14)")
    }

    func test_debugDescription_bool() {
        XCTAssertEqual(JSON.bool(true).debugDescription, "JSON.bool(true)")
    }

    func test_debugDescription_null() {
        XCTAssertEqual(JSON.null.debugDescription, "JSON.null")
    }

    // MARK: - JSONError.errorDescription

    func test_jsonError_errorDescription_unsupportedType() {
        let err = JSONError.unsupportedType("Foo")
        XCTAssertEqual(err.errorDescription, "Unsupported type: Foo")
    }

    func test_jsonError_errorDescription_invalidValue() {
        let err = JSONError.invalidValue("bad")
        XCTAssertEqual(err.errorDescription, "Invalid value: bad")
    }

    func test_jsonError_errorDescription_keyNotFound() {
        let err = JSONError.keyNotFound("myKey")
        XCTAssertEqual(err.errorDescription, "Key not found: 'myKey'")
    }

    func test_jsonError_errorDescription_indexOutOfBounds() {
        let err = JSONError.indexOutOfBounds(5)
        XCTAssertEqual(err.errorDescription, "Index out of bounds: 5")
    }

    func test_jsonError_errorDescription_typeMismatch() {
        let err = JSONError.typeMismatch(expected: "string", got: .number(1))
        XCTAssertNotNil(err.errorDescription)
        XCTAssertTrue(err.errorDescription!.contains("string"))
    }
}
