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
            additionalProperties: .bool(false),
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
            guard case JSONConvertibleError.decodingFailed(let underlying) = error else {
                return XCTFail("Expected JSONConvertibleError.decodingFailed, got \(error)")
            }
            // E3: The underlying error is the original DecodingError, not just a String.
            XCTAssertTrue(underlying is DecodingError, "underlying should be DecodingError")
        }
    }

    func test_decodingFailed_underlying_error_is_accessible() {
        do {
            _ = try Person.decode(from: #"{"name":999}"#)
            XCTFail("Expected throw")
        } catch let e as JSONConvertibleError {
            XCTAssertNotNil(e.underlyingError)
        } catch {
            XCTFail("Unexpected error type: \(error)")
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

    func test_schema_builder_description_and_title() {
        var builder = SchemaBuilder()
        builder.description("A great schema")
        builder.title("GreatSchema")
        builder.number("score")
        let schema = builder.build()
        XCTAssertEqual(schema.schemaDescription, "A great schema")
        XCTAssertEqual(schema.title, "GreatSchema")
    }

    // MARK: - E2: FluentSchemaBuilder (class-based)

    func test_fluent_builder_chaining() {
        let schema = FluentSchemaBuilder()
            .string("name", description: "Full name")
            .integer("age")
            .boolean("active", required: false)
            .build(title: "Person")

        XCTAssertEqual(schema.type, .object)
        XCTAssertEqual(schema.title, "Person")
        XCTAssertEqual(schema.properties?.count, 3)
        XCTAssertEqual(schema.required, ["name", "age"])
        XCTAssertNil(schema.required?.contains("active") == true ? "found" : nil)
    }

    func test_fluent_builder_with_title_and_description() {
        let schema = FluentSchemaBuilder()
            .withTitle("Item")
            .withDescription("An item")
            .string("label")
            .build()
        XCTAssertEqual(schema.title, "Item")
        XCTAssertEqual(schema.schemaDescription, "An item")
    }

    func test_fluent_builder_array_property() {
        let schema = FluentSchemaBuilder()
            .array("tags", items: .string(), minItems: 1, maxItems: 5)
            .build()
        XCTAssertEqual(schema.properties?["tags"]?.type, .array)
        XCTAssertEqual(schema.properties?["tags"]?.minItems, 1)
        XCTAssertEqual(schema.properties?["tags"]?.maxItems, 5)
    }

    func test_fluent_builder_object_property() {
        let addressSchema = JSONSchema.object(properties: ["city": .string()])
        let schema = FluentSchemaBuilder()
            .object("address", schema: addressSchema)
            .build()
        XCTAssertEqual(schema.properties?["address"]?.type, .object)
    }

    func test_fluent_builder_with_not_schema() {
        let schema = FluentSchemaBuilder()
            .string("status")
            .withNot(.string(enumValues: ["banned"]))
            .build(title: "SafeUser")
        XCTAssertNotNil(schema.not)
        XCTAssertEqual(schema.not?.enumValues, ["banned"])
        XCTAssertEqual(schema.title, "SafeUser")
    }

    func test_fluent_builder_without_not_has_nil_not() {
        let schema = FluentSchemaBuilder()
            .string("name")
            .build()
        XCTAssertNil(schema.not)
    }

    // MARK: - E2: @resultBuilder DSL

    func test_result_builder_basic() {
        let schema = JSONSchema.build(title: "Person") {
            JSONSchemaProperty.string("name", description: "Full name")
            JSONSchemaProperty.integer("age")
            JSONSchemaProperty.boolean("active", required: false)
        }
        XCTAssertEqual(schema.type, .object)
        XCTAssertEqual(schema.title, "Person")
        XCTAssertEqual(schema.properties?.count, 3)
        XCTAssertTrue(schema.required?.contains("name") == true)
        XCTAssertTrue(schema.required?.contains("age") == true)
        XCTAssertFalse(schema.required?.contains("active") == true)
    }

    func test_result_builder_array_property() {
        let schema = JSONSchema.build {
            JSONSchemaProperty.array("tags", items: .string(), minItems: 1)
        }
        XCTAssertEqual(schema.properties?["tags"]?.type, .array)
        XCTAssertEqual(schema.properties?["tags"]?.minItems, 1)
    }

    func test_result_builder_nested_object() {
        let schema = JSONSchema.build {
            JSONSchemaProperty.object("address", schema: .object(properties: ["city": .string()]))
        }
        XCTAssertEqual(schema.properties?["address"]?.type, .object)
    }

    func test_result_builder_with_constraints() {
        let schema = JSONSchema.build {
            JSONSchemaProperty.string("username", minLength: 3, maxLength: 20, pattern: "^[a-z]+$")
            JSONSchemaProperty.number("score", minimum: 0, maximum: 100)
            JSONSchemaProperty.integer("level", minimum: 1)
        }
        XCTAssertEqual(schema.properties?["username"]?.minLength, 3)
        XCTAssertEqual(schema.properties?["username"]?.maxLength, 20)
        XCTAssertNotNil(schema.properties?["username"]?.pattern)
        XCTAssertEqual(schema.properties?["score"]?.minimum, 0)
        XCTAssertEqual(schema.properties?["score"]?.maximum, 100)
        XCTAssertEqual(schema.properties?["level"]?.minimum, 1)
    }

    func test_result_builder_validates_correctly() {
        let schema = JSONSchema.build(title: "User") {
            JSONSchemaProperty.string("name")
            JSONSchemaProperty.integer("age", minimum: 0, maximum: 150)
        }
        let valid: JSON = ["name": "Alice", "age": 30]
        XCTAssertTrue(valid.isValid(against: schema))

        let invalid: JSON = ["name": "Bob", "age": 200]
        XCTAssertFalse(invalid.isValid(against: schema))
    }

    // MARK: - JSONConvertibleError.errorDescription

    func test_invalidResponse_error_description() {
        let err = JSONConvertibleError.invalidResponse("oops")
        XCTAssertTrue(err.errorDescription?.contains("oops") == true)
    }

    func test_schemaRequired_error_description() {
        let err = JSONConvertibleError.schemaRequired
        XCTAssertNotNil(err.errorDescription)
    }

    // MARK: - #31 JSONSchemaProviding protocol split

    func test_json_schema_providing_without_codable() {
        // Can conform to JSONSchemaProviding without Codable
        struct ViewConfig: JSONSchemaProviding {
            var isVisible: Bool
            static var jsonSchema: JSONSchema {
                .object(properties: ["isVisible": .boolean()], required: ["isVisible"])
            }
        }
        let schema = ViewConfig.jsonSchema
        XCTAssertEqual(schema.type, .object)
    }

    func test_json_convertible_is_json_schema_providing() {
        // JSONConvertible refines JSONSchemaProviding
        let _: JSONSchemaProviding.Type = Person.self
    }

    func test_json_schema_from_schema_providing_type() {
        struct Config: JSONSchemaProviding {
            static var jsonSchema: JSONSchema { .boolean() }
        }
        let schema = JSONSchema.from(Config.self)
        XCTAssertEqual(schema.type, .boolean)
    }
}
