//
//  JSONSchemaTests.swift
//  JSON
//
//  Created by Reid Chatham on 4/5/25.
//

import Testing
import Foundation
@testable import JSON

// MARK: - JSONSchema Tests

@Suite("JSONSchema")
struct JSONSchemaTests {
    @Test func stringSchema() {
        let schema = JSONSchema.string(description: "A name")
        #expect(schema.type == .string)
        #expect(schema.schemaDescription == "A name")
    }

    @Test func numberSchema() {
        let schema = JSONSchema.number(description: "A value")
        #expect(schema.type == .number)
        #expect(schema.schemaDescription == "A value")
    }

    @Test func integerSchema() {
        let schema = JSONSchema.integer()
        #expect(schema.type == .integer)
    }

    @Test func booleanSchema() {
        let schema = JSONSchema.boolean(description: "A flag")
        #expect(schema.type == .boolean)
    }

    @Test func arraySchema() {
        let schema = JSONSchema.array(items: .string(), description: "List of names")
        #expect(schema.type == .array)
        #expect(schema.items?.type == .string)
        #expect(schema.schemaDescription == "List of names")
    }

    @Test func objectSchema() {
        let schema = JSONSchema.object(
            properties: [
                "name": .string(description: "User name"),
                "age": .integer(description: "User age")
            ],
            required: ["name", "age"],
            additionalProperties: false,
            description: "A user object",
            title: "User"
        )
        #expect(schema.type == .object)
        #expect(schema.properties?.count == 2)
        #expect(schema.required == ["name", "age"])
        #expect(schema.additionalProperties == false)
        #expect(schema.title == "User")
        #expect(schema.schemaDescription == "A user object")
    }

    @Test func enumValuesOnString() {
        let schema = JSONSchema.string(description: "Unit", enumValues: ["celsius", "fahrenheit"])
        #expect(schema.enumValues == ["celsius", "fahrenheit"])
    }

    @Test func codableRoundTrip() throws {
        let schema = JSONSchema.object(
            properties: [
                "name": .string(description: "Name"),
                "scores": .array(items: .number(), description: "Scores"),
                "active": .boolean()
            ],
            required: ["name"],
            additionalProperties: false,
            description: "Test schema",
            title: "TestSchema"
        )

        let data = try JSONEncoder().encode(schema)
        let decoded = try JSONDecoder().decode(JSONSchema.self, from: data)
        #expect(schema == decoded)
    }

    @Test func encodesToValidJSON() throws {
        let schema = JSONSchema.object(
            properties: ["key": .string()],
            required: ["key"]
        )
        let data = try JSONEncoder().encode(schema)
        let jsonString = String(data: data, encoding: .utf8)!
        #expect(jsonString.contains("\"type\""))
        #expect(jsonString.contains("\"object\""))
        #expect(jsonString.contains("\"properties\""))
    }

    @Test func customStringConvertible() {
        let schema = JSONSchema.string(description: "test")
        let desc = schema.description
        #expect(desc.contains("string"))
    }

    @Test func nestedSchema() throws {
        let addressSchema = JSONSchema.object(
            properties: [
                "street": .string(),
                "city": .string(),
                "zip": .string()
            ],
            required: ["street", "city"]
        )
        let userSchema = JSONSchema.object(
            properties: [
                "name": .string(),
                "address": addressSchema
            ],
            required: ["name"]
        )
        #expect(userSchema.properties?["address"]?.type == .object)
        #expect(userSchema.properties?["address"]?.properties?["city"]?.type == .string)

        // Verify round-trip with nested schemas
        let data = try JSONEncoder().encode(userSchema)
        let decoded = try JSONDecoder().decode(JSONSchema.self, from: data)
        #expect(userSchema == decoded)
    }

    @Test func hashableUsableInSets() {
        let s1 = JSONSchema.string(description: "A")
        let s2 = JSONSchema.string(description: "A")
        let s3 = JSONSchema.number(description: "B")
        let set: Set<JSONSchema> = [s1, s2, s3]
        #expect(set.count == 2)
    }

    @Test func fromStructuredOutput() {
        struct TestOutput: StructuredOutput {
            let value: String
            static var jsonSchema: JSONSchema {
                .object(
                    properties: ["value": .string()],
                    required: ["value"]
                )
            }
        }
        let schema = JSONSchema.from(TestOutput.self)
        #expect(schema.type == .object)
        #expect(schema.properties?["value"]?.type == .string)
    }
}

// MARK: - StructuredOutput Tests

@Suite("StructuredOutput")
struct StructuredOutputTests {
    struct Weather: StructuredOutput {
        let location: String
        let temperature: Double
        let unit: String

        static var jsonSchema: JSONSchema {
            .object(
                properties: [
                    "location": .string(description: "City name"),
                    "temperature": .number(description: "Temperature value"),
                    "unit": .string(description: "Unit", enumValues: ["celsius", "fahrenheit"])
                ],
                required: ["location", "temperature", "unit"],
                additionalProperties: false,
                description: "Weather information"
            )
        }
    }

    @Test func protocolProvidesSchema() {
        let schema = Weather.jsonSchema
        #expect(schema.type == .object)
        #expect(schema.properties?.count == 3)
        #expect(schema.required?.count == 3)
        #expect(schema.additionalProperties == false)
    }

    @Test func schemaEncodesCorrectly() throws {
        let data = try JSONEncoder().encode(Weather.jsonSchema)
        let jsonString = String(data: data, encoding: .utf8)!
        #expect(jsonString.contains("\"location\""))
        #expect(jsonString.contains("\"temperature\""))
        #expect(jsonString.contains("\"unit\""))
        #expect(jsonString.contains("celsius"))
        #expect(jsonString.contains("fahrenheit"))
    }

    @Test func structuredOutputIsCodable() throws {
        let weather = Weather(location: "NYC", temperature: 72.5, unit: "fahrenheit")
        let data = try JSONEncoder().encode(weather)
        let decoded = try JSONDecoder().decode(Weather.self, from: data)
        #expect(decoded.location == "NYC")
        #expect(decoded.temperature == 72.5)
        #expect(decoded.unit == "fahrenheit")
    }

    @Test func fromFactoryMethod() {
        let schema = JSONSchema.from(Weather.self)
        #expect(schema == Weather.jsonSchema)
    }
}
