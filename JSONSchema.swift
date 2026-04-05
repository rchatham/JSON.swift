//
//  JSONSchema.swift
//  JSON.swift
//
//  Created by Reid Chatham on 4/5/25.
//

import Foundation

// MARK: - JSONSchema

/// Type-safe JSON Schema representation for structured output.
/// Follows the JSON Schema specification used by LLM providers.
/// Uses indirect storage for recursive properties to avoid Swift's value type recursion limitation.
public indirect enum JSONSchema: Codable, Sendable, Equatable {
    case schema(JSONSchemaDefinition)

    /// The underlying schema definition
    public var definition: JSONSchemaDefinition {
        switch self {
        case .schema(let def): return def
        }
    }

    // Forward common properties
    public var type: SchemaType { definition.type }
    public var properties: [String: JSONSchema]? { definition.properties }
    public var required: [String]? { definition.required }
    public var additionalProperties: Bool? { definition.additionalProperties }
    public var items: JSONSchema? { definition.items }
    public var enumValues: [String]? { definition.enumValues }
    public var schemaDescription: String? { definition.schemaDescription }
    public var title: String? { definition.title }

    /// Schema type enumeration
    public enum SchemaType: String, Codable, Sendable {
        case object
        case array
        case string
        case number
        case integer
        case boolean
        case null
    }

    /// Creates a JSONSchema with the specified properties.
    public init(
        type: SchemaType,
        properties: [String: JSONSchema]? = nil,
        required: [String]? = nil,
        additionalProperties: Bool? = nil,
        items: JSONSchema? = nil,
        enumValues: [String]? = nil,
        description: String? = nil,
        title: String? = nil
    ) {
        self = .schema(JSONSchemaDefinition(
            type: type,
            properties: properties,
            required: required,
            additionalProperties: additionalProperties,
            items: items,
            enumValues: enumValues,
            schemaDescription: description,
            title: title
        ))
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let definition = try JSONSchemaDefinition(from: decoder)
        self = .schema(definition)
    }

    public func encode(to encoder: Encoder) throws {
        try definition.encode(to: encoder)
    }

    // MARK: - Factory Methods

    /// Creates a string schema
    public static func string(description: String? = nil, enumValues: [String]? = nil) -> JSONSchema {
        JSONSchema(type: .string, enumValues: enumValues, description: description)
    }

    /// Creates a number schema
    public static func number(description: String? = nil) -> JSONSchema {
        JSONSchema(type: .number, description: description)
    }

    /// Creates an integer schema
    public static func integer(description: String? = nil) -> JSONSchema {
        JSONSchema(type: .integer, description: description)
    }

    /// Creates a boolean schema
    public static func boolean(description: String? = nil) -> JSONSchema {
        JSONSchema(type: .boolean, description: description)
    }

    /// Creates an array schema
    public static func array(items: JSONSchema, description: String? = nil) -> JSONSchema {
        JSONSchema(type: .array, items: items, description: description)
    }

    /// Creates an object schema
    public static func object(
        properties: [String: JSONSchema],
        required: [String]? = nil,
        additionalProperties: Bool = false,
        description: String? = nil,
        title: String? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .object,
            properties: properties,
            required: required,
            additionalProperties: additionalProperties,
            description: description,
            title: title
        )
    }

    /// Creates a schema from a StructuredOutput type
    public static func from<T: StructuredOutput>(_ type: T.Type) -> JSONSchema {
        T.jsonSchema
    }
}

/// Internal definition struct for JSONSchema storage
public struct JSONSchemaDefinition: Codable, Sendable, Equatable {
    public let type: JSONSchema.SchemaType
    public let properties: [String: JSONSchema]?
    public let required: [String]?
    public let additionalProperties: Bool?
    public let items: JSONSchema?
    public let enumValues: [String]?
    public let schemaDescription: String?
    public let title: String?

    public init(
        type: JSONSchema.SchemaType,
        properties: [String: JSONSchema]? = nil,
        required: [String]? = nil,
        additionalProperties: Bool? = nil,
        items: JSONSchema? = nil,
        enumValues: [String]? = nil,
        schemaDescription: String? = nil,
        title: String? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
        self.items = items
        self.enumValues = enumValues
        self.schemaDescription = schemaDescription
        self.title = title
    }

    // Custom CodingKeys to handle "enum" and "description" keywords
    enum CodingKeys: String, CodingKey {
        case type, properties, required, additionalProperties, items, title
        case enumValues = "enum"
        case schemaDescription = "description"
    }
}

// MARK: - JSONSchema CustomStringConvertible

extension JSONSchema: CustomStringConvertible {
    public var description: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "JSONSchema(type: \(type.rawValue))"
        }
        return string
    }
}
