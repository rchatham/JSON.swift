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

    // MARK: - #9 JSONError: Sendable

    func test_jsonError_sendable() {
        // Compile-time verification: JSONError can be stored in a Sendable context.
        let err: any Sendable = JSONError.keyNotFound("test")
        XCTAssertNotNil(err)
    }

    // MARK: - #11 Constants

    func test_empty_object_constant() {
        XCTAssertEqual(JSON.emptyObject, .object([:]))
        XCTAssertEqual(JSON.emptyObject.count, 0)
        XCTAssertTrue(JSON.emptyObject.isEmpty)
    }

    func test_empty_array_constant() {
        XCTAssertEqual(JSON.emptyArray, .array([]))
        XCTAssertEqual(JSON.emptyArray.count, 0)
        XCTAssertTrue(JSON.emptyArray.isEmpty)
    }

    // MARK: - #1 Equality operators (Optional<JSON> == primitives)

    func test_optional_json_equals_string() {
        let json: JSON? = .string("hello")
        XCTAssertTrue(json == "hello")
        XCTAssertTrue("hello" == json)
        XCTAssertFalse(json == "world")
        XCTAssertFalse("world" == json)
    }

    func test_optional_json_equals_int() {
        let json: JSON? = .number(42)
        XCTAssertTrue(json == 42)
        XCTAssertTrue(42 == json)
        XCTAssertFalse(json == 99)
    }

    func test_optional_json_equals_double() {
        let json: JSON? = .number(3.14)
        XCTAssertTrue(json == 3.14)
        XCTAssertFalse(json == 2.71)
    }

    func test_optional_json_equals_bool() {
        let json: JSON? = .bool(true)
        XCTAssertTrue(json == true)
        XCTAssertFalse(json == false)
    }

    func test_nil_optional_json_not_equal_to_string() {
        let json: JSON? = nil
        XCTAssertFalse(json == "hello")
        XCTAssertFalse("hello" == json)
    }

    func test_optional_json_neq_operators() {
        let json: JSON? = .string("a")
        XCTAssertTrue(json != "b")
        XCTAssertTrue("b" != json)
        XCTAssertFalse(json != "a")
    }

    // MARK: - #1 Pattern matching (~=)

    func test_pattern_matching_string() {
        let json: JSON = ["status": "active"]
        let matched: Bool
        switch json["status"] {
        case "active": matched = true
        default:       matched = false
        }
        XCTAssertTrue(matched)
    }

    func test_pattern_matching_int() {
        let json: JSON = ["code": 200]
        let matched: Bool
        switch json["code"] {
        case 200: matched = true
        default:  matched = false
        }
        XCTAssertTrue(matched)
    }

    func test_pattern_matching_bool() {
        let json: JSON = ["active": true]
        let matched: Bool
        switch json["active"] {
        case true: matched = true
        default:   matched = false
        }
        XCTAssertTrue(matched)
    }

    // MARK: - #2 Collection inspection

    func test_count_array() {
        let json: JSON = [1, 2, 3]
        XCTAssertEqual(json.count, 3)
    }

    func test_count_object() {
        let json: JSON = ["a": 1, "b": 2]
        XCTAssertEqual(json.count, 2)
    }

    func test_count_primitive_is_zero() {
        XCTAssertEqual(JSON.string("hi").count, 0)
        XCTAssertEqual(JSON.number(1).count, 0)
        XCTAssertEqual(JSON.null.count, 0)
    }

    func test_isEmpty_empty_array() {
        XCTAssertTrue(JSON.emptyArray.isEmpty)
    }

    func test_isEmpty_nonempty_array() {
        let json: JSON = [1]
        XCTAssertFalse(json.isEmpty)
    }

    func test_isEmpty_primitive() {
        // Non-null primitives are not "empty" — they carry a meaningful value.
        XCTAssertFalse(JSON.string("hi").isEmpty)
        XCTAssertFalse(JSON.number(42).isEmpty)
        XCTAssertFalse(JSON.bool(false).isEmpty)
        // Empty string IS considered empty.
        XCTAssertTrue(JSON.string("").isEmpty)
        // null is always empty (absent value).
        XCTAssertTrue(JSON.null.isEmpty)
    }

    func test_keys_returns_object_keys() {
        let json: JSON = ["a": 1, "b": 2]
        let keys = json.keys
        XCTAssertNotNil(keys)
        XCTAssertEqual(Set(keys!), ["a", "b"])
    }

    func test_keys_nil_for_non_object() {
        XCTAssertNil(JSON.array([1, 2]).keys)
        XCTAssertNil(JSON.string("hi").keys)
    }

    func test_values_returns_object_values() {
        let json: JSON = ["x": 1]
        let vals = json.values
        XCTAssertNotNil(vals)
        XCTAssertEqual(vals!, [.number(1)])
    }

    func test_contains_key_true() {
        let json: JSON = ["name": "Alice"]
        XCTAssertTrue(json.contains(key: "name"))
    }

    func test_contains_key_false() {
        let json: JSON = ["name": "Alice"]
        XCTAssertFalse(json.contains(key: "age"))
    }

    func test_contains_key_non_object_is_false() {
        XCTAssertFalse(JSON.array([1]).contains(key: "x"))
    }

    // MARK: - #3 Array / Object mutations

    func test_append_to_array() {
        var json: JSON = [1, 2]
        json.append(.number(3))
        XCTAssertEqual(json, .array([.number(1), .number(2), .number(3)]))
    }

    func test_append_contentsOf() {
        var json: JSON = [1]
        json.append(contentsOf: [.number(2), .number(3)])
        XCTAssertEqual(json.count, 3)
    }

    func test_append_noop_on_non_array() {
        var json: JSON = .string("hi")
        json.append(.number(1))
        XCTAssertEqual(json, .string("hi"))
    }

    func test_remove_at_index() {
        var json: JSON = [10, 20, 30]
        let removed = json.remove(at: 1)
        XCTAssertEqual(removed, .number(20))
        XCTAssertEqual(json, .array([.number(10), .number(30)]))
    }

    func test_remove_at_out_of_bounds_returns_nil() {
        var json: JSON = [1, 2]
        let removed = json.remove(at: 99)
        XCTAssertNil(removed)
    }

    func test_remove_value_for_key() {
        var json: JSON = ["a": 1, "b": 2]
        let removed = json.removeValue(forKey: "a")
        XCTAssertEqual(removed, .number(1))
        XCTAssertFalse(json.contains(key: "a"))
    }

    func test_remove_value_missing_key_returns_nil() {
        var json: JSON = ["a": 1]
        let removed = json.removeValue(forKey: "z")
        XCTAssertNil(removed)
    }

    // MARK: - #4 Throwing typed accessors

    func test_requireString_success() throws {
        let json = JSON.string("hello")
        XCTAssertEqual(try json.requireString(), "hello")
    }

    func test_requireString_throws_on_wrong_type() {
        XCTAssertThrowsError(try JSON.number(1).requireString())
    }

    func test_requireInt_success() throws {
        let json = JSON.number(42)
        XCTAssertEqual(try json.requireInt(), 42)
    }

    func test_requireInt_throws_on_fractional() {
        XCTAssertThrowsError(try JSON.number(3.14).requireInt())
    }

    func test_requireDouble_success() throws {
        let json = JSON.number(3.14)
        XCTAssertEqual(try json.requireDouble(), 3.14, accuracy: 0.001)
    }

    func test_requireBool_success() throws {
        XCTAssertTrue(try JSON.bool(true).requireBool())
        XCTAssertFalse(try JSON.bool(false).requireBool())
    }

    func test_requireArray_success() throws {
        let json: JSON = [1, 2, 3]
        let arr = try json.requireArray()
        XCTAssertEqual(arr.count, 3)
    }

    func test_requireObject_success() throws {
        let json: JSON = ["x": 1]
        let obj = try json.requireObject()
        XCTAssertEqual(obj["x"], .number(1))
    }

    func test_requireObject_throws_on_array() {
        XCTAssertThrowsError(try JSON.array([1]).requireObject())
    }

    // MARK: - #5 Typed extraction with defaults

    func test_string_forKey_found() {
        let json: JSON = ["name": "Alice"]
        XCTAssertEqual(json.string(forKey: "name"), "Alice")
    }

    func test_string_forKey_missing_returns_default() {
        let json: JSON = ["name": "Alice"]
        XCTAssertEqual(json.string(forKey: "missing", default: "fallback"), "fallback")
    }

    func test_int_forKey_found() {
        let json: JSON = ["age": 30]
        XCTAssertEqual(json.int(forKey: "age"), 30)
    }

    func test_int_forKey_missing_returns_zero() {
        let json: JSON = [:]
        XCTAssertEqual(json.int(forKey: "x"), 0)
    }

    func test_double_forKey_found() {
        let json: JSON = ["ratio": 3.14]
        XCTAssertEqual(json.double(forKey: "ratio"), 3.14, accuracy: 0.001)
    }

    func test_bool_forKey_found() {
        let json: JSON = ["active": true]
        XCTAssertTrue(json.bool(forKey: "active"))
    }

    func test_bool_forKey_missing_returns_false() {
        let json: JSON = [:]
        XCTAssertFalse(json.bool(forKey: "gone"))
    }

    // MARK: - #6 decode(as:) — JSONValueDecoder

    func test_decode_as_struct() throws {
        struct Point: Codable, Equatable { let x: Double; let y: Double }
        let json: JSON = ["x": 1.5, "y": 2.5]
        let point = try json.decode(as: Point.self)
        XCTAssertEqual(point, Point(x: 1.5, y: 2.5))
    }

    func test_decode_as_array() throws {
        let json: JSON = [1, 2, 3]
        let arr = try json.decode(as: [Int].self)
        XCTAssertEqual(arr, [1, 2, 3])
    }

    func test_decode_as_string() throws {
        let s = try JSON.string("hello").decode(as: String.self)
        XCTAssertEqual(s, "hello")
    }

    func test_decode_as_nested_struct() throws {
        struct Address: Codable, Equatable { let city: String }
        struct Person: Codable, Equatable { let name: String; let address: Address }
        let json: JSON = ["name": "Alice", "address": ["city": "Portland"]]
        let person = try json.decode(as: Person.self)
        XCTAssertEqual(person, Person(name: "Alice", address: Address(city: "Portland")))
    }

    func test_decode_with_custom_decoder() throws {
        struct Wrapper: Decodable { let value: String }
        let json: JSON = ["value": "test"]
        let decoder = JSONDecoder()
        let result = try json.decode(as: Wrapper.self, decoder: decoder)
        XCTAssertEqual(result.value, "test")
    }

    // MARK: - #12 Coercing accessors

    func test_coercedString_from_string() {
        XCTAssertEqual(JSON.string("hi").coercedString, "hi")
    }

    func test_coercedString_from_integer_number() {
        XCTAssertEqual(JSON.number(42).coercedString, "42")
    }

    func test_coercedString_from_float_number() {
        XCTAssertEqual(JSON.number(3.14).coercedString, "3.14")
    }

    func test_coercedString_from_bool() {
        XCTAssertEqual(JSON.bool(true).coercedString, "true")
        XCTAssertEqual(JSON.bool(false).coercedString, "false")
    }

    func test_coercedString_from_null() {
        XCTAssertEqual(JSON.null.coercedString, "null")
    }

    func test_coercedDouble_from_number() {
        XCTAssertEqual(JSON.number(3.14).coercedDouble ?? 0, 3.14, accuracy: 0.001)
    }

    func test_coercedDouble_from_string() {
        XCTAssertEqual(JSON.string("2.71").coercedDouble ?? 0, 2.71, accuracy: 0.001)
    }

    func test_coercedDouble_from_bool() {
        XCTAssertEqual(JSON.bool(true).coercedDouble, 1.0)
        XCTAssertEqual(JSON.bool(false).coercedDouble, 0.0)
    }

    func test_coercedDouble_nil_for_non_numeric_string() {
        XCTAssertNil(JSON.string("abc").coercedDouble)
    }

    func test_coercedBool_from_bool() {
        XCTAssertEqual(JSON.bool(true).coercedBool, true)
    }

    func test_coercedBool_from_number() {
        XCTAssertEqual(JSON.number(1).coercedBool, true)
        XCTAssertEqual(JSON.number(0).coercedBool, false)
    }

    func test_coercedBool_from_string_true() {
        XCTAssertEqual(JSON.string("true").coercedBool, true)
        XCTAssertEqual(JSON.string("yes").coercedBool, true)
        XCTAssertEqual(JSON.string("1").coercedBool, true)
    }

    func test_coercedBool_from_string_false() {
        XCTAssertEqual(JSON.string("false").coercedBool, false)
        XCTAssertEqual(JSON.string("no").coercedBool, false)
    }

    func test_coercedInt_from_number() {
        XCTAssertEqual(JSON.number(42).coercedInt, 42)
    }

    func test_coercedInt_from_string() {
        XCTAssertEqual(JSON.string("7").coercedInt, 7)
    }

    func test_coercedInt_nil_for_invalid_string() {
        XCTAssertNil(JSON.string("abc").coercedInt)
    }

    // MARK: - #18 JSON(encoding:encoder:)

    func test_init_encoding_with_custom_encoder() throws {
        struct Pair: Encodable { let a: Int; let b: Int }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try JSON(encoding: Pair(a: 1, b: 2), encoder: encoder)
        XCTAssertEqual(json["a"], .number(1))
        XCTAssertEqual(json["b"], .number(2))
    }

    // MARK: - #19 LosslessStringConvertible
    // Note: must use a variable (not literal) to avoid `ExpressibleByStringLiteral` taking over.

    func test_lossless_string_convertible_number() throws {
        let s: String = "42"
        let json = try XCTUnwrap(JSON(s))
        XCTAssertEqual(json, .number(42))
    }

    func test_lossless_string_convertible_quoted_string() throws {
        let s: String = "\"hello\""
        let json = try XCTUnwrap(JSON(s))
        XCTAssertEqual(json, .string("hello"))
    }

    func test_lossless_string_convertible_bool() throws {
        let ts: String = "true";  let fs: String = "false"
        let t = try XCTUnwrap(JSON(ts))
        let f = try XCTUnwrap(JSON(fs))
        XCTAssertEqual(t, .bool(true))
        XCTAssertEqual(f, .bool(false))
    }

    func test_lossless_string_convertible_null() throws {
        let s: String = "null"
        let json = try XCTUnwrap(JSON(s))
        XCTAssertEqual(json, .null)
    }

    func test_lossless_string_convertible_invalid_returns_nil() {
        let s: String = "not json {{{"
        XCTAssertNil(JSON(s))
    }

    // MARK: - #20 JSON Pointer (RFC 6901)

    func test_pointer_object_key() {
        let json: JSON = ["user": ["name": "Alice"]]
        XCTAssertEqual(json[pointer: "/user/name"], .string("Alice"))
    }

    func test_pointer_array_index() {
        let json: JSON = ["items": ["a", "b", "c"]]
        XCTAssertEqual(json[pointer: "/items/1"], .string("b"))
    }

    func test_pointer_tilde_escaping() {
        let json: JSON = ["a/b": "found"]
        XCTAssertEqual(json[pointer: "/a~1b"], .string("found"))
    }

    func test_pointer_tilde_zero_escaping() {
        let json: JSON = ["a~b": "found"]
        XCTAssertEqual(json[pointer: "/a~0b"], .string("found"))
    }

    func test_pointer_empty_string_returns_self() {
        let json: JSON = ["x": 1]
        XCTAssertEqual(json[pointer: ""], json)
    }

    func test_pointer_missing_key_returns_nil() {
        let json: JSON = ["a": 1]
        XCTAssertNil(json[pointer: "/b"])
    }

    func test_pointer_setter() {
        var json: JSON = ["user": ["name": "Alice"]]
        json[pointer: "/user/name"] = .string("Bob")
        XCTAssertEqual(json[pointer: "/user/name"], .string("Bob"))
    }

    // MARK: - #21 Comparable

    func test_comparable_null_less_than_bool() {
        XCTAssertLessThan(JSON.null, JSON.bool(false))
    }

    func test_comparable_bool_less_than_number() {
        XCTAssertLessThan(JSON.bool(true), JSON.number(0))
    }

    func test_comparable_numbers() {
        XCTAssertLessThan(JSON.number(1), JSON.number(2))
    }

    func test_comparable_strings_alphabetical() {
        XCTAssertLessThan(JSON.string("apple"), JSON.string("banana"))
    }

    func test_comparable_enables_sorting() {
        let arr: [JSON] = [.number(3), .number(1), .number(2)]
        let sorted = arr.sorted()
        XCTAssertEqual(sorted, [.number(1), .number(2), .number(3)])
    }

    // MARK: - #22 CustomReflectable

    func test_custom_reflectable_string() {
        let mirror = Mirror(reflecting: JSON.string("hi"))
        XCTAssertNotNil(mirror.children.first)
    }

    func test_custom_reflectable_array_display_style() {
        let json: JSON = [1, 2, 3]
        let mirror = Mirror(reflecting: json)
        XCTAssertEqual(mirror.displayStyle, .collection)
    }

    func test_custom_reflectable_object_display_style() {
        let json: JSON = ["a": 1]
        let mirror = Mirror(reflecting: json)
        XCTAssertEqual(mirror.displayStyle, .dictionary)
    }

    // MARK: - #23 isInteger

    func test_is_integer_whole_number() {
        XCTAssertTrue(JSON.number(42.0).isInteger)
        XCTAssertTrue(JSON.number(0.0).isInteger)
        XCTAssertTrue(JSON.number(-5.0).isInteger)
    }

    func test_is_integer_fractional_is_false() {
        XCTAssertFalse(JSON.number(3.14).isInteger)
    }

    func test_is_integer_non_number_is_false() {
        XCTAssertFalse(JSON.string("42").isInteger)
        XCTAssertFalse(JSON.bool(true).isInteger)
        XCTAssertFalse(JSON.null.isInteger)
    }

    // MARK: - #29 JSON Diff

    func test_diff_identical_values_is_empty() {
        let json: JSON = ["a": 1, "b": 2]
        let diff = json.diff(from: json)
        XCTAssertTrue(diff.isEmpty)
    }

    func test_diff_added_key() {
        let old: JSON = ["a": 1]
        let new: JSON = ["a": 1, "b": 2]
        let diff = new.diff(from: old)
        XCTAssertEqual(diff.additions.count, 1)
        if case .added(let path, let value) = diff.additions[0] {
            XCTAssertEqual(path, "root.b")
            XCTAssertEqual(value, .number(2))
        } else {
            XCTFail("Expected .added change")
        }
    }

    func test_diff_removed_key() {
        let old: JSON = ["a": 1, "b": 2]
        let new: JSON = ["a": 1]
        let diff = new.diff(from: old)
        XCTAssertEqual(diff.removals.count, 1)
        XCTAssertEqual(diff.removals[0].path, "root.b")
    }

    func test_diff_modified_value() {
        let old: JSON = ["age": 30]
        let new: JSON = ["age": 31]
        let diff = new.diff(from: old)
        XCTAssertEqual(diff.modifications.count, 1)
        if case .modified(let path, let from, let to) = diff.modifications[0] {
            XCTAssertEqual(path, "root.age")
            XCTAssertEqual(from, .number(30))
            XCTAssertEqual(to, .number(31))
        } else {
            XCTFail("Expected .modified change")
        }
    }

    func test_diff_nested_change() {
        let old: JSON = ["user": ["name": "Alice"]]
        let new: JSON = ["user": ["name": "Bob"]]
        let diff = new.diff(from: old)
        XCTAssertFalse(diff.isEmpty)
        XCTAssertEqual(diff.modifications[0].path, "root.user.name")
    }

    func test_diff_array_change() {
        let old: JSON = [1, 2, 3]
        let new: JSON = [1, 99, 3]
        let diff = new.diff(from: old)
        XCTAssertEqual(diff.modifications.count, 1)
        XCTAssertEqual(diff.modifications[0].path, "root[1]")
    }
}
