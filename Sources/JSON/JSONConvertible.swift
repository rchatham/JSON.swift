//
//  JSONConvertible.swift
//  JSON
//
//  Created by Reid Chatham on 4/5/25.
//

import Foundation

// MARK: - JSONConvertible Protocol

/// A type that can describe its own JSON Schema.
///
/// Conforming types provide a static `jsonSchema` property that describes their shape as a
/// `JSONSchema`. This is typically used for LLM structured output, schema validation, or
/// code-generation workflows.
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
public protocol JSONConvertible: Codable, Sendable {
    /// The JSON Schema that describes instances of this type.
    static var jsonSchema: JSONSchema { get }
}

// MARK: - JSONConvertibleError

/// A `Sendable`-safe wrapper for an arbitrary `Error` value.
private struct SendableError: Error, @unchecked Sendable {
    let wrapped: Error
}

/// Errors thrown when working with `JSONConvertible` types.
public enum JSONConvertibleError: Error, LocalizedError, Sendable {
    case invalidResponse(String)
    /// Wraps the underlying decoding error. The payload is `@unchecked Sendable`
    /// because `Error` itself does not conform to `Sendable`.
    case decodingFailed(String)
    case schemaRequired

    public var errorDescription: String? {
        switch self {
        case .invalidResponse(let msg): return "Invalid structured response: \(msg)"
        case .decodingFailed(let msg):  return "Failed to decode structured response: \(msg)"
        case .schemaRequired:           return "Response schema is required for structured output requests"
        }
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
            throw JSONConvertibleError.decodingFailed(error.localizedDescription)
        }
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
        additionalProperties: Bool = false
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
