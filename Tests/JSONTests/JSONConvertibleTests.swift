//
//  JSONConvertibleTests.swift
//  JSONTests
//
//  Created by Reid Chatham on 4/5/25.
//

import XCTest
@testable import JSON

// MARK: - Fixtures

private struct Person: JSONConvertible {
    let name: String
    let age: Int
    let email: String?

    static var jsonSchema: JSONSchema {
        .object(
            properties: [
                "name":  .string(description: "Full name"),
                "age":   .integer(description: "Age in years"),
                "email": .string(description: "Email address"),
            ],
            required: ["name", "age"],
            additionalProperties: false,
            title: "Person"
        )
    }
}

private struct Team: JSONConvertible {
    let name: String
    let members: [Person]

    static var jsonSchema: JSONSchema {
        .object(
            properties: [
                "name":    .string(),
                "members": .array(items: .from(Person.self)),
            ],
            required: ["name", "members"]
        )
    }
}

// MARK: - Tests

final class JSONConvertibleTests: XCTestCase {

    // MARK: - decode(from:)

    func test_decode_from_string() throws {
        let person = try Person.decode(from: #"{"name":"Alice","age":30}"#)
        XCTAssertEqual(person.name, "Alice")
        XCTAssertEqual(person.age, 30)
        XCTAssertNil(person.email)
    }

    func test_decode_from_data() throws {
        let data = #"{"name":"Bob","age":25,"email":"bob@example.com"}"#.data(using: .utf8)!
        let person = try Person.decode(from: data)
        XCTAssertEqual(person.name, "Bob")
        XCTAssertEqual(person.age, 25)
        XCTAssertEqual(person.email, "bob@example.com")
    }

    func test_decode_invalid_throws_decodingFailed() {
        // name is String but JSON has a number — should throw decodingFailed
        XCTAssertThrowsError(try Person.decode(from: #"{"name":123}"#)) { error in
            if case JSONConvertibleError.decodingFailed = error { return }
            XCTFail("Expected JSONConvertibleError.decodingFailed, got \(error)")
        }
    }

    func test_decode_invalid_json_string_throws() {
        XCTAssertThrowsError(try Person.decode(from: "not json"))
    }

    // MARK: - jsonSchema properties

    func test_person_schema_type() {
        XCTAssertEqual(Person.jsonSchema.type, .object)
    }

    func test_person_schema_required() {
        XCTAssertEqual(Person.jsonSchema.required, ["name", "age"])
    }

    func test_person_schema_properties() {
        let props = Person.jsonSchema.properties
        XCTAssertEqual(props?["name"]?.type, .string)
        XCTAssertEqual(props?["age"]?.type, .integer)
        XCTAssertEqual(props?["email"]?.type, .string)
    }

    func test_person_schema_title() {
        XCTAssertEqual(Person.jsonSchema.title, "Person")
    }

    func test_team_schema_nested_from() {
        let membersSchema = Team.jsonSchema.properties?["members"]
        XCTAssertEqual(membersSchema?.type, .array)
        XCTAssertEqual(membersSchema?.items?.type, .object)
    }

    // MARK: - JSONSchema.from(_:)

    func test_from_returns_same_as_static_property() {
        XCTAssertEqual(JSONSchema.from(Person.self), Person.jsonSchema)
    }

    // MARK: - SchemaBuilder

    func test_schema_builder_builds_correctly() {
        var builder = SchemaBuilder()
        builder.string("title", description: "Book title")
        builder.integer("pages")
        builder.boolean("inPrint", required: false)
        let schema = builder.build(title: "Book")

        XCTAssertEqual(schema.type, .object)
        XCTAssertEqual(schema.title, "Book")
        XCTAssertEqual(schema.required, ["title", "pages"])
        XCTAssertEqual(schema.properties?.count, 3)
    }

    func test_schema_builder_array_property() {
        var builder = SchemaBuilder()
        builder.array("tags", items: .string())
        let schema = builder.build()
        XCTAssertEqual(schema.properties?["tags"]?.type, .array)
        XCTAssertEqual(schema.properties?["tags"]?.items?.type, .string)
    }

    func test_schema_builder_nested_object() {
        let addressSchema = JSONSchema.object(properties: ["city": .string()])
        var builder = SchemaBuilder()
        builder.object("address", schema: addressSchema)
        let schema = builder.build()
        XCTAssertEqual(schema.properties?["address"]?.type, .object)
    }

    func test_schema_builder_empty_required_is_nil() {
        var builder = SchemaBuilder()
        builder.string("opt", required: false)
        let schema = builder.build()
        XCTAssertNil(schema.required)
    }

    func test_schema_builder_chaining() {
        // Each call mutates `builder` in place and returns self.
        // Sequential calls accumulate all three properties.
        var builder = SchemaBuilder()
        builder.string("a")
        builder.integer("b")
        builder.boolean("c")
        let schema = builder.build()
        XCTAssertEqual(schema.properties?.count, 3)
        XCTAssertEqual(schema.required?.count, 3)
    }
}
