//
//  StructuredOutput.swift
//  JSON
//
//  Created by Reid Chatham on 4/5/25.
//

import Foundation

// MARK: - StructuredOutput

/// A protocol for types that can describe themselves as a JSON Schema.
///
/// Conform to `StructuredOutput` to provide a schema definition for your
/// `Codable` types, enabling use with LLM providers and other systems
/// that require structured JSON Schema descriptions.
///
/// ```swift
/// struct Weather: Codable, StructuredOutput {
///     let location: String
///     let temperature: Double
///     let unit: String
///
///     static var jsonSchema: JSONSchema {
///         .object(
///             properties: [
///                 "location": .string(description: "City name"),
///                 "temperature": .number(description: "Temperature value"),
///                 "unit": .string(description: "Unit of measurement", enumValues: ["celsius", "fahrenheit"])
///             ],
///             required: ["location", "temperature", "unit"],
///             description: "Weather information"
///         )
///     }
/// }
/// ```
public protocol StructuredOutput: Codable, Sendable {
    /// The JSON Schema describing this type's structure.
    static var jsonSchema: JSONSchema { get }
}
