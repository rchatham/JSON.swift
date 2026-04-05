//
//  JSONTests.swift
//  JSON
//
//  Created by Reid Chatham on 4/5/25.
//

import Testing
import Foundation
@testable import JSON

// MARK: - Codable Tests

@Suite("JSON Codable")
struct JSONCodableTests {
    @Test func decodesString() throws {
        let json = try JSON(string: #""hello""#)
        #expect(json == .string("hello"))
    }

    @Test func decodesNumber() throws {
        let json = try JSON(string: "42.5")
        #expect(json == .number(42.5))
    }

    @Test func decodesInteger() throws {
        let json = try JSON(string: "10")
        #expect(json == .number(10.0))
    }

    @Test func decodesBoolTrue() throws {
        let json = try JSON(string: "true")
        #expect(json == .bool(true))
    }

    @Test func decodesBoolFalse() throws {
        let json = try JSON(string: "false")
        #expect(json == .bool(false))
    }

    @Test func decodesNull() throws {
        let json = try JSON(string: "null")
        #expect(json == .null)
    }

    @Test func decodesArray() throws {
        let json = try JSON(string: #"[1, "two", true, null]"#)
        #expect(json == .array([.number(1), .string("two"), .bool(true), .null]))
    }

    @Test func decodesObject() throws {
        let json = try JSON(string: #"{"key": "value", "num": 42}"#)
        #expect(json == .object(["key": .string("value"), "num": .number(42)]))
    }

    @Test func decodesNestedStructure() throws {
        let jsonString = #"{"users": [{"name": "Alice", "age": 30}, {"name": "Bob", "age": 25}]}"#
        let json = try JSON(string: jsonString)
        let expected: JSON = .object([
            "users": .array([
                .object(["name": .string("Alice"), "age": .number(30)]),
                .object(["name": .string("Bob"), "age": .number(25)])
            ])
        ])
        #expect(json == expected)
    }

    @Test func roundTrip() throws {
        let original: JSON = .object([
            "string": .string("hello"),
            "number": .number(3.14),
            "bool": .bool(true),
            "null": .null,
            "array": .array([.number(1), .number(2)]),
            "nested": .object(["key": .string("value")])
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSON.self, from: data)
        #expect(original == decoded)
    }

    @Test func invalidJSONStringThrows() {
        #expect(throws: (any Error).self) {
            try JSON(string: "not valid json")
        }
    }

    @Test func encodesToValidJSON() throws {
        let json: JSON = .object(["name": .string("test"), "count": .number(5)])
        let data = try JSONEncoder().encode(json)
        let string = String(data: data, encoding: .utf8)
        #expect(string != nil)
        #expect(string!.contains("\"name\""))
        #expect(string!.contains("\"test\""))
    }
}

// MARK: - Convenience Initializer Tests

@Suite("JSON Convenience Initializers")
struct JSONConvenienceInitTests {
    @Test func initFromNil() throws {
        let json = try JSON(nil as Any?)
        #expect(json == .null)
    }

    @Test func initFromString() throws {
        let json = try JSON("hello" as Any)
        #expect(json == .string("hello"))
    }

    @Test func initFromDouble() throws {
        let json = try JSON(3.14 as Any)
        #expect(json == .number(3.14))
    }

    @Test func initFromInt() throws {
        let json = try JSON(42 as Any)
        #expect(json == .number(42.0))
    }

    @Test func initFromBool() throws {
        let json = try JSON(true as Any)
        #expect(json == .bool(true))
    }

    @Test func initFromArray() throws {
        let json = try JSON(["a", "b"] as [Any?])
        #expect(json == .array([.string("a"), .string("b")]))
    }

    @Test func initFromDictionary() throws {
        let json = try JSON(["key": "value"] as [String: Any?])
        #expect(json == .object(["key": .string("value")]))
    }

    @Test func initFromUnsupportedTypeThrows() {
        #expect(throws: JSONError.self) {
            try JSON(Date() as Any)
        }
    }

    @Test func initFromEncodable() throws {
        struct Foo: Codable {
            let name: String
            let age: Int
        }
        let foo = Foo(name: "test", age: 30)
        let json = try JSON(encoding: foo)
        #expect(json["name"]?.stringValue == "test")
        #expect(json["age"]?.intValue == 30)
    }
}

// MARK: - Value Extraction Tests

@Suite("JSON Value Extraction")
struct JSONValueExtractionTests {
    @Test func stringValue() {
        #expect(JSON.string("hello").stringValue == "hello")
        #expect(JSON.number(42).stringValue == nil)
    }

    @Test func doubleValue() {
        #expect(JSON.number(3.14).doubleValue == 3.14)
        #expect(JSON.string("nope").doubleValue == nil)
    }

    @Test func intValue() {
        #expect(JSON.number(42).intValue == 42)
        #expect(JSON.string("nope").intValue == nil)
    }

    @Test func boolValue() {
        #expect(JSON.bool(true).boolValue == true)
        #expect(JSON.number(1).boolValue == nil)
    }

    @Test func arrayValue() {
        let arr: [JSON] = [.number(1), .number(2)]
        #expect(JSON.array(arr).arrayValue == arr)
        #expect(JSON.string("nope").arrayValue == nil)
    }

    @Test func objectValue() {
        let obj: [String: JSON] = ["key": .string("value")]
        #expect(JSON.object(obj).objectValue == obj)
        #expect(JSON.string("nope").objectValue == nil)
    }

    @Test func isNull() {
        #expect(JSON.null.isNull == true)
        #expect(JSON.string("").isNull == false)
    }

    @Test func count() {
        #expect(JSON.array([.number(1), .number(2)]).count == 2)
        #expect(JSON.object(["a": .number(1)]).count == 1)
        #expect(JSON.string("hello").count == nil)
    }

    @Test func jsonString() {
        let json: JSON = .object(["key": .string("value")])
        let str = json.jsonString
        #expect(str != nil)
        #expect(str!.contains("\"key\""))
    }

    @Test func compactJSONString() {
        let json: JSON = .object(["key": .string("value")])
        let str = json.compactJSONString
        #expect(str != nil)
        #expect(!str!.contains("\n"))
    }

    @Test func decodeToType() throws {
        struct Person: Codable, Equatable {
            let name: String
            let age: Int
        }
        let json: JSON = .object(["name": .string("Alice"), "age": .number(30)])
        let person = try json.decode(Person.self)
        #expect(person == Person(name: "Alice", age: 30))
    }
}

// MARK: - Subscript Tests

@Suite("JSON Subscripts")
struct JSONSubscriptTests {
    @Test func objectKeyAccess() {
        let json: JSON = .object(["name": .string("Alice")])
        #expect(json["name"] == .string("Alice"))
        #expect(json["missing"] == nil)
    }

    @Test func arrayIndexAccess() {
        let json: JSON = .array([.string("a"), .string("b"), .string("c")])
        #expect(json[0] == .string("a"))
        #expect(json[2] == .string("c"))
        #expect(json[10] == nil)
        #expect(json[-1] == nil)
    }

    @Test func subscriptOnWrongType() {
        let json: JSON = .string("not an object")
        #expect(json["key"] == nil)
        #expect(json[0] == nil)
    }

    @Test func mutableObjectSubscript() {
        var json: JSON = .object(["a": .number(1)])
        json["b"] = .number(2)
        #expect(json["b"] == .number(2))
        json["a"] = nil
        #expect(json["a"] == nil)
    }

    @Test func mutableArraySubscript() {
        var json: JSON = .array([.string("a"), .string("b")])
        json[0] = .string("z")
        #expect(json[0] == .string("z"))
    }

    @Test func dynamicMemberLookup() {
        let json: JSON = .object(["name": .string("Alice"), "age": .number(30)])
        #expect(json.name == .string("Alice"))
        #expect(json.age == .number(30))
        #expect(json.missing == nil)
    }

    @Test func mutableDynamicMemberLookup() {
        var json: JSON = .object(["name": .string("Alice")])
        json.name = .string("Bob")
        #expect(json.name == .string("Bob"))
    }

    @Test func nestedAccess() throws {
        let jsonString = #"{"user": {"address": {"city": "NYC"}}}"#
        let json = try JSON(string: jsonString)
        #expect(json.user?.address?.city?.stringValue == "NYC")
    }
}

// MARK: - Merge Tests

@Suite("JSON Merge")
struct JSONMergeTests {
    @Test func mergeObjects() {
        let a: JSON = .object(["a": .number(1), "b": .number(2)])
        let b: JSON = .object(["b": .number(3), "c": .number(4)])
        let merged = a.merging(b)
        #expect(merged["a"] == .number(1))
        #expect(merged["b"] == .number(3))
        #expect(merged["c"] == .number(4))
    }

    @Test func deepMerge() {
        let a: JSON = .object(["nested": .object(["x": .number(1), "y": .number(2)])])
        let b: JSON = .object(["nested": .object(["y": .number(3), "z": .number(4)])])
        let merged = a.merging(b)
        #expect(merged.nested?["x"] == .number(1))
        #expect(merged.nested?["y"] == .number(3))
        #expect(merged.nested?["z"] == .number(4))
    }

    @Test func mergeNonObjectReplacesValue() {
        let a: JSON = .string("old")
        let b: JSON = .string("new")
        #expect(a.merging(b) == .string("new"))
    }

    @Test func mutatingMerge() {
        var json: JSON = .object(["a": .number(1)])
        json.merge(.object(["b": .number(2)]))
        #expect(json["a"] == .number(1))
        #expect(json["b"] == .number(2))
    }
}

// MARK: - Literal Tests

@Suite("JSON Literals")
struct JSONLiteralTests {
    @Test func stringLiteral() {
        let json: JSON = "hello"
        #expect(json == .string("hello"))
    }

    @Test func integerLiteral() {
        let json: JSON = 42
        #expect(json == .number(42.0))
    }

    @Test func floatLiteral() {
        let json: JSON = 3.14
        #expect(json == .number(3.14))
    }

    @Test func booleanLiteral() {
        let json: JSON = true
        #expect(json == .bool(true))
    }

    @Test func arrayLiteral() {
        let json: JSON = [1, "two", true]
        #expect(json == .array([.number(1), .string("two"), .bool(true)]))
    }

    @Test func dictionaryLiteral() {
        let json: JSON = ["name": "Alice", "age": 30]
        #expect(json == .object(["name": .string("Alice"), "age": .number(30)]))
    }

    @Test func nilLiteral() {
        let json: JSON = nil
        #expect(json == .null)
    }

    @Test func nestedLiterals() {
        let json: JSON = [
            "user": [
                "name": "Alice",
                "scores": [95, 87, 100]
            ]
        ]
        #expect(json.user?.name?.stringValue == "Alice")
        #expect(json.user?.scores?[0] == .number(95))
    }
}

// MARK: - Equatable & Hashable Tests

@Suite("JSON Equatable & Hashable")
struct JSONEquatableHashableTests {
    @Test func equalValues() {
        #expect(JSON.string("a") == JSON.string("a"))
        #expect(JSON.number(1) == JSON.number(1))
        #expect(JSON.bool(true) == JSON.bool(true))
        #expect(JSON.null == JSON.null)
    }

    @Test func unequalValues() {
        #expect(JSON.string("a") != JSON.number(1))
        #expect(JSON.bool(true) != JSON.bool(false))
        #expect(JSON.null != JSON.string("null"))
    }

    @Test func hashableUsableInSets() {
        let set: Set<JSON> = [.string("a"), .number(1), .string("a")]
        #expect(set.count == 2)
    }

    @Test func hashableUsableAsDictionaryKeys() {
        let dict: [JSON: String] = [
            .string("key"): "value",
            .number(42): "number"
        ]
        #expect(dict[.string("key")] == "value")
        #expect(dict[.number(42)] == "number")
    }
}

// MARK: - JSONError Tests

@Suite("JSONError")
struct JSONErrorTests {
    @Test func errorDescriptions() {
        let e1 = JSONError.unsupportedType("Date")
        #expect(e1.errorDescription?.contains("Date") == true)

        let e2 = JSONError.invalidValue("bad")
        #expect(e2.errorDescription?.contains("bad") == true)

        let e3 = JSONError.keyNotFound("missing")
        #expect(e3.errorDescription?.contains("missing") == true)

        let e4 = JSONError.indexOutOfBounds(99)
        #expect(e4.errorDescription?.contains("99") == true)
    }
}

// MARK: - Description Tests

@Suite("JSON Description")
struct JSONDescriptionTests {
    @Test func customStringConvertible() {
        let json: JSON = .object(["key": .string("value")])
        let desc = json.description
        #expect(desc.contains("key"))
        #expect(desc.contains("value"))
    }

    @Test func customDebugStringConvertible() {
        #expect(JSON.string("hi").debugDescription == #"JSON.string("hi")"#)
        #expect(JSON.number(42).debugDescription == "JSON.number(42.0)")
        #expect(JSON.bool(true).debugDescription == "JSON.bool(true)")
        #expect(JSON.null.debugDescription == "JSON.null")
        #expect(JSON.array([]).debugDescription == "JSON.array(0 elements)")
        #expect(JSON.object([:]).debugDescription == "JSON.object(0 keys)")
    }
}

// MARK: - Dictionary Extension Tests

@Suite("Dictionary JSON Extension")
struct DictionaryJSONExtensionTests {
    @Test func dictionaryStringRepresentation() {
        let dict: [String: JSON] = ["name": .string("Alice"), "age": .number(30)]
        let str = dict.string
        #expect(str != nil)
        #expect(str!.contains("Alice"))
        #expect(str!.contains("30"))
    }
}
