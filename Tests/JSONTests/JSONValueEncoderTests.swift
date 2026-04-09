//
//  JSONValueEncoderTests.swift
//  JSONTests
//

import XCTest
@testable import JSON

final class JSONValueEncoderTests: XCTestCase {

    private let encoder = JSONValueEncoder()

    // MARK: - Primitives

    func test_encode_string() throws {
        let json = try encoder.encode("hello")
        XCTAssertEqual(json, .string("hello"))
    }

    func test_encode_int() throws {
        XCTAssertEqual(try encoder.encode(42),     .number(42))
        XCTAssertEqual(try encoder.encode(Int8(8)), .number(8))
        XCTAssertEqual(try encoder.encode(Int64(9_000_000_000)), .number(9_000_000_000))
    }

    func test_encode_uint() throws {
        XCTAssertEqual(try encoder.encode(UInt(7)),    .number(7))
        XCTAssertEqual(try encoder.encode(UInt32(99)), .number(99))
    }

    func test_encode_double() throws {
        XCTAssertEqual(try encoder.encode(3.14), .number(3.14))
    }

    func test_encode_float() throws {
        let json = try encoder.encode(Float(2.5))
        XCTAssertEqual(json, .number(Double(Float(2.5))))
    }

    func test_encode_bool_true() throws {
        XCTAssertEqual(try encoder.encode(true),  .bool(true))
        XCTAssertEqual(try encoder.encode(false), .bool(false))
    }

    func test_encode_optional_nil() throws {
        let value: String? = nil
        XCTAssertEqual(try encoder.encode(value), .null)
    }

    func test_encode_optional_some() throws {
        let value: String? = "hi"
        XCTAssertEqual(try encoder.encode(value), .string("hi"))
    }

    // MARK: - Arrays

    func test_encode_int_array() throws {
        let json = try encoder.encode([1, 2, 3])
        XCTAssertEqual(json, .array([.number(1), .number(2), .number(3)]))
    }

    func test_encode_string_array() throws {
        let json = try encoder.encode(["a", "b"])
        XCTAssertEqual(json, .array([.string("a"), .string("b")]))
    }

    func test_encode_mixed_array() throws {
        // Encode [Any] via typed Encodable wrapping
        struct Wrapper: Encodable {
            func encode(to encoder: Encoder) throws {
                var c = encoder.unkeyedContainer()
                try c.encode("hello")
                try c.encode(42)
                try c.encode(true)
                try c.encodeNil()
            }
        }
        let json = try encoder.encode(Wrapper())
        XCTAssertEqual(json, .array([.string("hello"), .number(42), .bool(true), .null]))
    }

    func test_encode_nested_array() throws {
        let json = try encoder.encode([[1, 2], [3, 4]])
        XCTAssertEqual(json, .array([.array([.number(1), .number(2)]),
                                     .array([.number(3), .number(4)])]))
    }

    // MARK: - Structs / objects

    func test_encode_simple_struct() throws {
        struct Point: Encodable { let x: Double; let y: Double }
        let json = try encoder.encode(Point(x: 1.5, y: 2.5))
        XCTAssertEqual(json["x"], .number(1.5))
        XCTAssertEqual(json["y"], .number(2.5))
    }

    func test_encode_nested_struct() throws {
        struct Address: Encodable { let city: String }
        struct Person: Encodable { let name: String; let address: Address }
        let json = try encoder.encode(Person(name: "Alice", address: Address(city: "Portland")))
        XCTAssertEqual(json["name"], .string("Alice"))
        XCTAssertEqual(json["address"]?["city"], .string("Portland"))
    }

    func test_encode_struct_with_optional_nil() throws {
        struct Wrapper: Encodable { let value: String? }
        let json = try encoder.encode(Wrapper(value: nil))
        // Swift's Codable synthesis uses `encodeIfPresent` — the key is
        // omitted entirely (not written as null) when the optional is nil.
        XCTAssertNil(json["value"])
    }

    func test_encode_struct_with_optional_some() throws {
        struct Wrapper: Encodable { let value: String? }
        let json = try encoder.encode(Wrapper(value: "present"))
        XCTAssertEqual(json["value"], .string("present"))
    }

    func test_encode_struct_with_array_field() throws {
        struct Bag: Encodable { let items: [String] }
        let json = try encoder.encode(Bag(items: ["a", "b", "c"]))
        XCTAssertEqual(json["items"], .array([.string("a"), .string("b"), .string("c")]))
    }

    // MARK: - Dictionary

    func test_encode_string_keyed_dict() throws {
        let json = try encoder.encode(["x": 1, "y": 2])
        XCTAssertEqual(json["x"], .number(1))
        XCTAssertEqual(json["y"], .number(2))
    }

    // MARK: - JSON round-trip (encode → decode)

    func test_roundtrip_struct() throws {
        struct Point: Codable, Equatable { let x: Double; let y: Double }
        let original = Point(x: 3.14, y: 2.71)
        let json  = try encoder.encode(original)
        let back  = try JSONValueDecoder().decode(Point.self, from: json)
        XCTAssertEqual(back, original)
    }

    func test_roundtrip_nested_struct() throws {
        struct Inner: Codable, Equatable { let value: Int }
        struct Outer: Codable, Equatable { let inner: Inner; let tag: String }
        let original = Outer(inner: Inner(value: 42), tag: "hello")
        let json = try encoder.encode(original)
        let back = try JSONValueDecoder().decode(Outer.self, from: json)
        XCTAssertEqual(back, original)
    }

    func test_roundtrip_array_of_structs() throws {
        struct Item: Codable, Equatable { let id: Int; let name: String }
        let original = [Item(id: 1, name: "a"), Item(id: 2, name: "b")]
        let json = try encoder.encode(original)
        let back = try JSONValueDecoder().decode([Item].self, from: json)
        XCTAssertEqual(back, original)
    }

    // MARK: - JSON value passthrough

    func test_encode_json_string_directly() throws {
        let json = try encoder.encode(JSON.string("hello"))
        XCTAssertEqual(json, .string("hello"))
    }

    func test_encode_json_object_directly() throws {
        let original: JSON = ["key": .number(1), "flag": .bool(true)]
        let json = try encoder.encode(original)
        XCTAssertEqual(json, original)
    }

    func test_encode_json_array_directly() throws {
        let original: JSON = [1, "two", true, nil]
        let json = try encoder.encode(original)
        XCTAssertEqual(json, original)
    }

    // MARK: - CodingKeys support

    func test_encode_respects_coding_keys() throws {
        struct Item: Encodable {
            let firstName: String
            enum CodingKeys: String, CodingKey { case firstName = "first_name" }
        }
        let json = try encoder.encode(Item(firstName: "Alice"))
        XCTAssertEqual(json["first_name"], .string("Alice"))
        XCTAssertNil(json["firstName"])
    }

    // MARK: - JSON(encoding:) uses JSONValueEncoder

    func test_json_init_encoding_uses_value_encoder() throws {
        struct Point: Encodable { let x: Double; let y: Double }
        let json = try JSON(encoding: Point(x: 1, y: 2))
        XCTAssertEqual(json["x"], .number(1))
        XCTAssertEqual(json["y"], .number(2))
    }

    func test_json_init_encoding_array() throws {
        let json = try JSON(encoding: [1, 2, 3])
        XCTAssertEqual(json, .array([.number(1), .number(2), .number(3)]))
    }

    func test_json_init_encoding_string() throws {
        let json = try JSON(encoding: "hello")
        XCTAssertEqual(json, .string("hello"))
    }

    // MARK: - userInfo forwarding

    func test_user_info_forwarded_to_containers() throws {
        let key = CodingUserInfoKey(rawValue: "testKey")!
        struct InfoConsumer: Encodable {
            func encode(to encoder: Encoder) throws {
                _ = encoder.userInfo[CodingUserInfoKey(rawValue: "testKey")!]
                var c = encoder.singleValueContainer()
                try c.encode("ok")
            }
        }
        var enc = JSONValueEncoder()
        enc.userInfo[key] = "value"
        let json = try enc.encode(InfoConsumer())
        XCTAssertEqual(json, .string("ok"))
    }
}
