//
//  JSONConvertible.swift
//  JSON
//
//  Created by Reid Chatham on 4/5/25.
//

import Foundation

// MARK: - #31 JSONSchemaProviding protocol (schema without requiring Codable)

/// A type that can describe its own JSON Schema.
///
/// `JSONSchemaProviding` is the schema-only protocol — it does **not** require `Codable`.
/// This allows non-Codable types (view models, etc.) to describe their JSON shape for
/// documentation, validation, or LLM structured output.
///
/// ```swift
/// struct Config: JSONSchemaProviding {
///     static var jsonSchema: JSONSchema {
///         .object(properties: ["debug": .boolean()], required: ["debug"])
///     }
/// }
/// ```
public protocol JSONSchemaProviding: Sendable {
    /// The JSON Schema that describes instances of this type.
    static var jsonSchema: JSONSchema { get }
}

// MARK: - JSONConvertible Protocol

/// A type that provides a JSON Schema **and** is `Codable`.
///
/// This is the standard protocol for types that participate in JSON encode/decode
/// **and** schema-driven validation or LLM structured output.
///
/// You can implement conformance manually:
/// ```swift
/// struct WeatherCard: JSONConvertible {
///     let location: String
///     let temperature: Double
///
///     static var jsonSchema: JSONSchema {
///         .object(
///             properties: [
///                 "location":    .string(description: "City name"),
///                 "temperature": .number(description: "Degrees Celsius"),
///             ],
///             required: ["location", "temperature"]
///         )
///     }
/// }
/// ```
///
/// Or use the `@JSONSchema` macro to have it generated automatically:
/// ```swift
/// @JSONSchema
/// struct WeatherCard: Codable {
///     let location: String
///     let temperature: Double
/// }
/// ```
public protocol JSONConvertible: Codable, JSONSchemaProviding {}

// MARK: - JSONConvertibleError

/// A `Sendable`-safe wrapper for an arbitrary `Error` value.
private struct SendableError: Error, @unchecked Sendable {
    let wrapped: Error
}

/// Errors thrown when working with `JSONConvertible` types.
public enum JSONConvertibleError: Error, LocalizedError {
    case invalidResponse(String)
    /// Wraps the underlying decoding error so callers can inspect structured failure detail.
    case decodingFailed(Error)
    case schemaRequired

    public var errorDescription: String? {
        switch self {
        case .invalidResponse(let msg):  return "Invalid structured response: \(msg)"
        case .decodingFailed(let error): return "Failed to decode structured response: \(error.localizedDescription)"
        case .schemaRequired:            return "Response schema is required for structured output requests"
        }
    }

    /// The underlying error for `.decodingFailed`, or `nil` for other cases.
    public var underlyingError: Error? {
        if case .decodingFailed(let e) = self { return e }
        return nil
    }
}

// MARK: - Decoding Helpers

extension JSONConvertible {
    /// Decodes an instance from a JSON string.
    public static func decode(from jsonString: String) throws -> Self {
        guard let data = jsonString.data(using: .utf8) else {
            throw JSONConvertibleError.invalidResponse("String could not be converted to UTF-8 data")
        }
        return try decode(from: data)
    }

    /// Decodes an instance from raw `Data`.
    public static func decode(from data: Data) throws -> Self {
        do {
            return try JSONDecoder().decode(Self.self, from: data)
        } catch {
            throw JSONConvertibleError.decodingFailed(error)
        }
    }
}

// MARK: - JSONSchemaProperty (result-builder element)

/// A single named property definition used inside a `JSONSchema { ... }` result-builder block.
///
/// Create instances via the static factory methods:
/// ```swift
/// JSONSchemaProperty.string("name", description: "Full name")
/// JSONSchemaProperty.integer("age", required: false)
/// ```
public struct JSONSchemaProperty: Sendable {
    let name: String
    let schema: JSONSchema
    let required: Bool

    // MARK: Factories

    /// A `string` property.
    public static func string(
        _ name: String,
        required: Bool = true,
        description: String? = nil,
        enumValues: [String]? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        pattern: String? = nil
    ) -> JSONSchemaProperty {
        JSONSchemaProperty(
            name: name,
            schema: .string(description: description, enumValues: enumValues,
                            minLength: minLength, maxLength: maxLength, pattern: pattern),
            required: required
        )
    }

    /// A `number` property.
    public static func number(
        _ name: String,
        required: Bool = true,
        description: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil
    ) -> JSONSchemaProperty {
        JSONSchemaProperty(
            name: name,
            schema: .number(description: description, minimum: minimum, maximum: maximum),
            required: required
        )
    }

    /// An `integer` property.
    public static func integer(
        _ name: String,
        required: Bool = true,
        description: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil
    ) -> JSONSchemaProperty {
        JSONSchemaProperty(
            name: name,
            schema: .integer(description: description, minimum: minimum, maximum: maximum),
            required: required
        )
    }

    /// A `boolean` property.
    public static func boolean(
        _ name: String,
        required: Bool = true,
        description: String? = nil
    ) -> JSONSchemaProperty {
        JSONSchemaProperty(name: name, schema: .boolean(description: description), required: required)
    }

    /// An `array` property.
    public static func array(
        _ name: String,
        items: JSONSchema,
        required: Bool = true,
        description: String? = nil,
        minItems: Int? = nil,
        maxItems: Int? = nil
    ) -> JSONSchemaProperty {
        JSONSchemaProperty(
            name: name,
            schema: .array(items: items, description: description, minItems: minItems, maxItems: maxItems),
            required: required
        )
    }

    /// A nested `object` property with a pre-built schema.
    public static func object(
        _ name: String,
        schema: JSONSchema,
        required: Bool = true
    ) -> JSONSchemaProperty {
        JSONSchemaProperty(name: name, schema: schema, required: required)
    }

    /// A property with a custom schema (for composition types or `JSONConvertible` types).
    public static func custom(
        _ name: String,
        schema: JSONSchema,
        required: Bool = true
    ) -> JSONSchemaProperty {
        JSONSchemaProperty(name: name, schema: schema, required: required)
    }
}

// MARK: - JSONSchemaBuilder (@resultBuilder)

/// A result builder that assembles a list of `JSONSchemaProperty` values into a `JSONSchema`.
///
/// Use this inside `JSONSchema.build { ... }` blocks for a declarative, SwiftUI-style syntax:
/// ```swift
/// let schema = JSONSchema.build(title: "Person") {
///     JSONSchemaProperty.string("name", description: "Full name")
///     JSONSchemaProperty.integer("age")
///     JSONSchemaProperty.string("email", required: false)
/// }
/// ```
@resultBuilder
public struct JSONSchemaBuilder {
    public static func buildBlock(_ properties: JSONSchemaProperty...) -> [JSONSchemaProperty] {
        properties
    }
    public static func buildArray(_ components: [[JSONSchemaProperty]]) -> [JSONSchemaProperty] {
        components.flatMap { $0 }
    }
    public static func buildOptional(_ component: [JSONSchemaProperty]?) -> [JSONSchemaProperty] {
        component ?? []
    }
    public static func buildEither(first component: [JSONSchemaProperty]) -> [JSONSchemaProperty] {
        component
    }
    public static func buildEither(second component: [JSONSchemaProperty]) -> [JSONSchemaProperty] {
        component
    }
}

// MARK: - JSONSchema result-builder factory

extension JSONSchema {
    /// Creates an object schema using a declarative result-builder block.
    ///
    /// ```swift
    /// let schema = JSONSchema.build(title: "Person") {
    ///     JSONSchemaProperty.string("name", description: "Full name")
    ///     JSONSchemaProperty.integer("age")
    ///     JSONSchemaProperty.string("email", required: false)
    /// }
    /// ```
    public static func build(
        title: String? = nil,
        description: String? = nil,
        additionalProperties: AdditionalProperties = .bool(false),
        @JSONSchemaBuilder _ content: () -> [JSONSchemaProperty]
    ) -> JSONSchema {
        let props = content()
        let properties = Dictionary(uniqueKeysWithValues: props.map { ($0.name, $0.schema) })
        let required = props.filter(\.required).map(\.name)
        return .object(
            properties: properties,
            required: required.isEmpty ? nil : required,
            additionalProperties: additionalProperties,
            description: description,
            title: title
        )
    }
}

// MARK: - FluentSchemaBuilder (class-based, true method chaining)

/// A class-based builder that enables true fluent method chaining in a single expression.
///
/// Unlike the `struct`-based `SchemaBuilder`, every mutating method returns `self` by
/// reference, so calls can be chained without a `var` binding:
///
/// ```swift
/// let schema = FluentSchemaBuilder()
///     .string("name", description: "Full name")
///     .integer("age")
///     .boolean("active", required: false)
///     .build(title: "Person")
/// ```
public final class FluentSchemaBuilder {
    private var properties: [String: JSONSchema] = [:]
    private var requiredProperties: [String] = []
    private var schemaDescription: String?
    private var schemaTitle: String?

    public init() {}

    // MARK: Property adders

    @discardableResult
    public func string(
        _ name: String,
        required: Bool = true,
        description: String? = nil,
        enumValues: [String]? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        pattern: String? = nil
    ) -> FluentSchemaBuilder {
        properties[name] = .string(description: description, enumValues: enumValues,
                                   minLength: minLength, maxLength: maxLength, pattern: pattern)
        if required { requiredProperties.append(name) }
        return self
    }

    @discardableResult
    public func number(
        _ name: String,
        required: Bool = true,
        description: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil
    ) -> FluentSchemaBuilder {
        properties[name] = .number(description: description, minimum: minimum, maximum: maximum)
        if required { requiredProperties.append(name) }
        return self
    }

    @discardableResult
    public func integer(
        _ name: String,
        required: Bool = true,
        description: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil
    ) -> FluentSchemaBuilder {
        properties[name] = .integer(description: description, minimum: minimum, maximum: maximum)
        if required { requiredProperties.append(name) }
        return self
    }

    @discardableResult
    public func boolean(
        _ name: String,
        required: Bool = true,
        description: String? = nil
    ) -> FluentSchemaBuilder {
        properties[name] = .boolean(description: description)
        if required { requiredProperties.append(name) }
        return self
    }

    @discardableResult
    public func array(
        _ name: String,
        items: JSONSchema,
        required: Bool = true,
        description: String? = nil,
        minItems: Int? = nil,
        maxItems: Int? = nil
    ) -> FluentSchemaBuilder {
        properties[name] = .array(items: items, description: description,
                                  minItems: minItems, maxItems: maxItems)
        if required { requiredProperties.append(name) }
        return self
    }

    @discardableResult
    public func object(
        _ name: String,
        schema: JSONSchema,
        required: Bool = true,
        description: String? = nil
    ) -> FluentSchemaBuilder {
        properties[name] = schema
        if required { requiredProperties.append(name) }
        return self
    }

    @discardableResult
    public func withDescription(_ description: String) -> FluentSchemaBuilder {
        schemaDescription = description
        return self
    }

    @discardableResult
    public func withTitle(_ title: String) -> FluentSchemaBuilder {
        schemaTitle = title
        return self
    }

    /// Builds the final `JSONSchema`.
    public func build(
        title: String? = nil,
        description: String? = nil,
        additionalProperties: AdditionalProperties = .bool(false)
    ) -> JSONSchema {
        .object(
            properties: properties,
            required: requiredProperties.isEmpty ? nil : requiredProperties,
            additionalProperties: additionalProperties,
            description: description ?? schemaDescription,
            title: title ?? schemaTitle
        )
    }
}

// MARK: - SchemaBuilder DSL

/// An imperative builder for constructing `JSONSchema` object schemas.
///
/// All property-adder methods are `@discardableResult` and return `Self` so
/// they can be chained. Because `SchemaBuilder` is a `struct`, each mutation
/// updates the receiver in-place; the return value is the same `self` (useful
/// for temporary inline chains via `var`).
///
/// For true method chaining in a single expression, use `FluentSchemaBuilder` instead.
/// For a declarative SwiftUI-style syntax, use `JSONSchema.build { ... }`.
///
/// ```swift
/// var builder = SchemaBuilder()
/// builder
///     .string("name", description: "Full name")
///     .integer("age")
///     .boolean("active", required: false)
/// let schema = builder.build(title: "Person")
/// ```
public struct SchemaBuilder {
    private var properties: [String: JSONSchema] = [:]
    private var requiredProperties: [String] = []
    private var schemaDescription: String?
    private var schemaTitle: String?

    public init() {}

    // MARK: Property adders

    @discardableResult
    public mutating func string(
        _ name: String,
        required: Bool = true,
        description: String? = nil,
        enumValues: [String]? = nil
    ) -> SchemaBuilder {
        properties[name] = .string(description: description, enumValues: enumValues)
        if required { requiredProperties.append(name) }
        return self
    }

    @discardableResult
    public mutating func number(
        _ name: String,
        required: Bool = true,
        description: String? = nil
    ) -> SchemaBuilder {
        properties[name] = .number(description: description)
        if required { requiredProperties.append(name) }
        return self
    }

    @discardableResult
    public mutating func integer(
        _ name: String,
        required: Bool = true,
        description: String? = nil
    ) -> SchemaBuilder {
        properties[name] = .integer(description: description)
        if required { requiredProperties.append(name) }
        return self
    }

    @discardableResult
    public mutating func boolean(
        _ name: String,
        required: Bool = true,
        description: String? = nil
    ) -> SchemaBuilder {
        properties[name] = .boolean(description: description)
        if required { requiredProperties.append(name) }
        return self
    }

    @discardableResult
    public mutating func array(
        _ name: String,
        items: JSONSchema,
        required: Bool = true,
        description: String? = nil
    ) -> SchemaBuilder {
        properties[name] = .array(items: items, description: description)
        if required { requiredProperties.append(name) }
        return self
    }

    @discardableResult
    public mutating func object(
        _ name: String,
        schema: JSONSchema,
        required: Bool = true
    ) -> SchemaBuilder {
        properties[name] = schema
        if required { requiredProperties.append(name) }
        return self
    }

    @discardableResult
    public mutating func description(_ description: String) -> SchemaBuilder {
        schemaDescription = description
        return self
    }

    @discardableResult
    public mutating func title(_ title: String) -> SchemaBuilder {
        schemaTitle = title
        return self
    }

    /// Builds the final `JSONSchema`.
    public func build(
        title: String? = nil,
        description: String? = nil,
        additionalProperties: AdditionalProperties = .bool(false)
    ) -> JSONSchema {
        .object(
            properties: properties,
            required: requiredProperties.isEmpty ? nil : requiredProperties,
            additionalProperties: additionalProperties,
            description: description ?? schemaDescription,
            title: title ?? schemaTitle
        )
    }
}
