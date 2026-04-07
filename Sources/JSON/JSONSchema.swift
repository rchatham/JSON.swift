//
//  JSONSchema.swift
//  JSON
//
//  Created by Reid Chatham on 4/5/25.
//

import Foundation

// MARK: - Heap Box (for recursive value types)

/// A heap-allocated reference wrapper that allows a value type to store
/// a reference to another instance of itself without infinite layout recursion.
final class Box<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

// MARK: - JSONSchema

/// Type-safe JSON Schema representation.
///
/// `JSONSchema` follows the [JSON Schema specification](https://json-schema.org) and is
/// designed for describing structured output shapes for LLM providers, validation,
/// and code generation.
///
/// Build schemas using the factory static methods:
/// ```swift
/// let schema = JSONSchema.object(
///     properties: [
///         "name": .string(description: "The user's name"),
///         "age":  .integer(description: "The user's age"),
///         "role": .string(enumValues: ["admin", "user"]),
///     ],
///     required: ["name", "age"]
/// )
/// ```
///
/// Compose schemas with `anyOf` for nullable or union types:
/// ```swift
/// let nullable = JSONSchema.anyOf([.string(), .null()])
/// ```
///
/// Derive a schema from any `JSONConvertible` type:
/// ```swift
/// let schema = JSONSchema.from(MyResponse.self)
/// ```
public struct JSONSchema: Sendable {

    // MARK: - Schema Type

    /// Primitive types defined by the JSON Schema specification.
    public enum SchemaType: String, Codable, Sendable, CaseIterable {
        case object, array, string, number, integer, boolean, null
    }

    // MARK: - Stored Properties

    /// The primitive type of this schema, if it has one.
    /// `nil` for composition schemas (`anyOf`, `oneOf`, `allOf`).
    public let type: SchemaType?

    /// Object properties (for `type == .object`).
    public let properties: [String: JSONSchema]?

    /// Required property keys (for `type == .object`).
    public let required: [String]?

    /// Whether additional properties are allowed (for `type == .object`).
    public let additionalProperties: Bool?

    /// Array item schema (for `type == .array`).
    ///
    /// Stored via a heap-allocated box to break the value-type recursion.
    public var items: JSONSchema? { _items?.value }
    private let _items: Box<JSONSchema>?

    /// Allowed string values (for `type == .string`).
    public let enumValues: [String]?

    /// Human-readable description for documentation and LLM context.
    public let schemaDescription: String?

    /// Schema title.
    public let title: String?

    /// Composition: value must be valid against at least one subschema.
    public let anyOf: [JSONSchema]?

    /// Composition: value must be valid against exactly one subschema.
    public let oneOf: [JSONSchema]?

    /// Composition: value must be valid against all subschemas.
    public let allOf: [JSONSchema]?

    // MARK: - Numeric constraints (number / integer)

    /// The inclusive minimum numeric value allowed.
    public let minimum: Double?

    /// The inclusive maximum numeric value allowed.
    public let maximum: Double?

    /// The exclusive minimum numeric value (value must be strictly greater than this).
    public let exclusiveMinimum: Double?

    /// The exclusive maximum numeric value (value must be strictly less than this).
    public let exclusiveMaximum: Double?

    // MARK: - String constraints

    /// The minimum number of characters allowed (inclusive).
    public let minLength: Int?

    /// The maximum number of characters allowed (inclusive).
    public let maxLength: Int?

    /// A regular-expression pattern the string must match (ECMA 262 dialect).
    public let pattern: String?

    // MARK: - Array constraints

    /// The minimum number of items in the array (inclusive).
    public let minItems: Int?

    /// The maximum number of items in the array (inclusive).
    public let maxItems: Int?

    /// When `true`, all array items must be unique.
    public let uniqueItems: Bool?

    // MARK: - Designated Initializer

    public init(
        type: SchemaType? = nil,
        properties: [String: JSONSchema]? = nil,
        required: [String]? = nil,
        additionalProperties: Bool? = nil,
        items: JSONSchema? = nil,
        enumValues: [String]? = nil,
        description: String? = nil,
        title: String? = nil,
        anyOf: [JSONSchema]? = nil,
        oneOf: [JSONSchema]? = nil,
        allOf: [JSONSchema]? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        exclusiveMinimum: Double? = nil,
        exclusiveMaximum: Double? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        pattern: String? = nil,
        minItems: Int? = nil,
        maxItems: Int? = nil,
        uniqueItems: Bool? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
        self._items = items.map(Box.init)
        self.enumValues = enumValues
        self.schemaDescription = description
        self.title = title
        self.anyOf = anyOf
        self.oneOf = oneOf
        self.allOf = allOf
        self.minimum = minimum
        self.maximum = maximum
        self.exclusiveMinimum = exclusiveMinimum
        self.exclusiveMaximum = exclusiveMaximum
        self.minLength = minLength
        self.maxLength = maxLength
        self.pattern = pattern
        self.minItems = minItems
        self.maxItems = maxItems
        self.uniqueItems = uniqueItems
    }

    // MARK: - Factory Methods — Primitives

    /// Creates a `string` schema, optionally constraining to a fixed set of values or length.
    public static func string(
        description: String? = nil,
        enumValues: [String]? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        pattern: String? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .string,
            enumValues: enumValues,
            description: description,
            minLength: minLength,
            maxLength: maxLength,
            pattern: pattern
        )
    }

    /// Creates a `number` (floating-point) schema with optional range constraints.
    public static func number(
        description: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        exclusiveMinimum: Double? = nil,
        exclusiveMaximum: Double? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .number,
            description: description,
            minimum: minimum,
            maximum: maximum,
            exclusiveMinimum: exclusiveMinimum,
            exclusiveMaximum: exclusiveMaximum
        )
    }

    /// Creates an `integer` schema with optional range constraints.
    public static func integer(
        description: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        exclusiveMinimum: Double? = nil,
        exclusiveMaximum: Double? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .integer,
            description: description,
            minimum: minimum,
            maximum: maximum,
            exclusiveMinimum: exclusiveMinimum,
            exclusiveMaximum: exclusiveMaximum
        )
    }

    /// Creates a `boolean` schema.
    public static func boolean(description: String? = nil) -> JSONSchema {
        JSONSchema(type: .boolean, description: description)
    }

    /// Creates a `null` schema.
    public static func null(description: String? = nil) -> JSONSchema {
        JSONSchema(type: .null, description: description)
    }

    // MARK: - Factory Methods — Compound

    /// Creates an `array` schema with the given item schema and optional length constraints.
    public static func array(
        items: JSONSchema,
        description: String? = nil,
        minItems: Int? = nil,
        maxItems: Int? = nil,
        uniqueItems: Bool? = nil
    ) -> JSONSchema {
        JSONSchema(
            type: .array,
            items: items,
            description: description,
            minItems: minItems,
            maxItems: maxItems,
            uniqueItems: uniqueItems
        )
    }

    /// Creates an `object` schema.
    public static func object(
        properties: [String: JSONSchema] = [:],
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

    // MARK: - Factory Methods — Composition

    /// Creates an `anyOf` schema: valid against **at least one** of the subschemas.
    ///
    /// Use this to represent nullable fields:
    /// ```swift
    /// let maybeString = JSONSchema.anyOf([.string(), .null()])
    /// ```
    public static func anyOf(_ schemas: [JSONSchema], description: String? = nil) -> JSONSchema {
        JSONSchema(description: description, anyOf: schemas)
    }

    /// Creates a `oneOf` schema: valid against **exactly one** of the subschemas.
    public static func oneOf(_ schemas: [JSONSchema], description: String? = nil) -> JSONSchema {
        JSONSchema(description: description, oneOf: schemas)
    }

    /// Creates an `allOf` schema: valid against **all** of the subschemas.
    public static func allOf(_ schemas: [JSONSchema], description: String? = nil) -> JSONSchema {
        JSONSchema(description: description, allOf: schemas)
    }

    // MARK: - Convenience

    /// Wraps this schema as nullable: `anyOf([self, .null()])`.
    public var nullable: JSONSchema { .anyOf([self, .null()]) }

    /// Derives a schema from a `JSONConvertible` conforming type.
    public static func from<T: JSONConvertible>(_ type: T.Type) -> JSONSchema {
        T.jsonSchema
    }

    // MARK: - Shared Encoder

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}

// MARK: - Codable

extension JSONSchema: Codable {

    enum CodingKeys: String, CodingKey {
        case type, properties, required, additionalProperties, items, title
        case enumValues = "enum"
        case schemaDescription = "description"
        case anyOf, oneOf, allOf
        case minimum, maximum, exclusiveMinimum, exclusiveMaximum
        case minLength, maxLength, pattern
        case minItems, maxItems, uniqueItems
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type                 = try container.decodeIfPresent(SchemaType.self,           forKey: .type)
        properties           = try container.decodeIfPresent([String: JSONSchema].self, forKey: .properties)
        required             = try container.decodeIfPresent([String].self,             forKey: .required)
        additionalProperties = try container.decodeIfPresent(Bool.self,                 forKey: .additionalProperties)
        let rawItems         = try container.decodeIfPresent(JSONSchema.self,           forKey: .items)
        _items               = rawItems.map(Box.init)
        enumValues           = try container.decodeIfPresent([String].self,             forKey: .enumValues)
        schemaDescription    = try container.decodeIfPresent(String.self,               forKey: .schemaDescription)
        title                = try container.decodeIfPresent(String.self,               forKey: .title)
        anyOf                = try container.decodeIfPresent([JSONSchema].self,         forKey: .anyOf)
        oneOf                = try container.decodeIfPresent([JSONSchema].self,         forKey: .oneOf)
        allOf                = try container.decodeIfPresent([JSONSchema].self,         forKey: .allOf)
        minimum              = try container.decodeIfPresent(Double.self,               forKey: .minimum)
        maximum              = try container.decodeIfPresent(Double.self,               forKey: .maximum)
        exclusiveMinimum     = try container.decodeIfPresent(Double.self,               forKey: .exclusiveMinimum)
        exclusiveMaximum     = try container.decodeIfPresent(Double.self,               forKey: .exclusiveMaximum)
        minLength            = try container.decodeIfPresent(Int.self,                  forKey: .minLength)
        maxLength            = try container.decodeIfPresent(Int.self,                  forKey: .maxLength)
        pattern              = try container.decodeIfPresent(String.self,               forKey: .pattern)
        minItems             = try container.decodeIfPresent(Int.self,                  forKey: .minItems)
        maxItems             = try container.decodeIfPresent(Int.self,                  forKey: .maxItems)
        uniqueItems          = try container.decodeIfPresent(Bool.self,                 forKey: .uniqueItems)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type,                 forKey: .type)
        try container.encodeIfPresent(properties,           forKey: .properties)
        try container.encodeIfPresent(required,             forKey: .required)
        try container.encodeIfPresent(additionalProperties, forKey: .additionalProperties)
        try container.encodeIfPresent(items,                forKey: .items)
        try container.encodeIfPresent(enumValues,           forKey: .enumValues)
        try container.encodeIfPresent(schemaDescription,    forKey: .schemaDescription)
        try container.encodeIfPresent(title,                forKey: .title)
        try container.encodeIfPresent(anyOf,                forKey: .anyOf)
        try container.encodeIfPresent(oneOf,                forKey: .oneOf)
        try container.encodeIfPresent(allOf,                forKey: .allOf)
        try container.encodeIfPresent(minimum,              forKey: .minimum)
        try container.encodeIfPresent(maximum,              forKey: .maximum)
        try container.encodeIfPresent(exclusiveMinimum,     forKey: .exclusiveMinimum)
        try container.encodeIfPresent(exclusiveMaximum,     forKey: .exclusiveMaximum)
        try container.encodeIfPresent(minLength,            forKey: .minLength)
        try container.encodeIfPresent(maxLength,            forKey: .maxLength)
        try container.encodeIfPresent(pattern,              forKey: .pattern)
        try container.encodeIfPresent(minItems,             forKey: .minItems)
        try container.encodeIfPresent(maxItems,             forKey: .maxItems)
        try container.encodeIfPresent(uniqueItems,          forKey: .uniqueItems)
    }
}

// MARK: - Equatable

extension JSONSchema: Equatable {
    public static func == (lhs: JSONSchema, rhs: JSONSchema) -> Bool {
        lhs.type == rhs.type &&
        lhs.properties == rhs.properties &&
        lhs.required == rhs.required &&
        lhs.additionalProperties == rhs.additionalProperties &&
        lhs.items == rhs.items &&
        lhs.enumValues == rhs.enumValues &&
        lhs.schemaDescription == rhs.schemaDescription &&
        lhs.title == rhs.title &&
        lhs.anyOf == rhs.anyOf &&
        lhs.oneOf == rhs.oneOf &&
        lhs.allOf == rhs.allOf &&
        lhs.minimum == rhs.minimum &&
        lhs.maximum == rhs.maximum &&
        lhs.exclusiveMinimum == rhs.exclusiveMinimum &&
        lhs.exclusiveMaximum == rhs.exclusiveMaximum &&
        lhs.minLength == rhs.minLength &&
        lhs.maxLength == rhs.maxLength &&
        lhs.pattern == rhs.pattern &&
        lhs.minItems == rhs.minItems &&
        lhs.maxItems == rhs.maxItems &&
        lhs.uniqueItems == rhs.uniqueItems
    }
}

// MARK: - Hashable

extension JSONSchema: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(schemaDescription)
        hasher.combine(title)
        hasher.combine(required)
        hasher.combine(additionalProperties)
        hasher.combine(enumValues)
        hasher.combine(minimum)
        hasher.combine(maximum)
        hasher.combine(exclusiveMinimum)
        hasher.combine(exclusiveMaximum)
        hasher.combine(minLength)
        hasher.combine(maxLength)
        hasher.combine(pattern)
        hasher.combine(minItems)
        hasher.combine(maxItems)
        hasher.combine(uniqueItems)
        // properties, items, anyOf, oneOf, allOf are Hashable via their own conformances
        if let props = properties {
            hasher.combine(props)
        }
        if let it = items {
            hasher.combine(it)
        }
        if let any = anyOf {
            hasher.combine(any)
        }
        if let one = oneOf {
            hasher.combine(one)
        }
        if let all = allOf {
            hasher.combine(all)
        }
    }
}

// MARK: - CustomStringConvertible

extension JSONSchema: CustomStringConvertible {
    public var description: String {
        guard let data = try? JSONSchema.encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "JSONSchema(type: \(type?.rawValue ?? "composition"))"
        }
        return string
    }
}
