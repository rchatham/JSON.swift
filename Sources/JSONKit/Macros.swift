//
//  Macros.swift
//  JSONKit
//
//  Created by Reid Chatham on 4/5/25.
//

// MARK: - @JSONSchema Macro Declaration

/// Automatically synthesizes `JSONConvertible` conformance for a `struct`.
///
/// The macro inspects stored properties and generates a `jsonSchema` static property
/// that reflects the property names and types. It also respects any `CodingKeys` enum
/// defined on the struct, using the encoded key names rather than Swift property names.
///
/// Supported Swift property types and their schema mappings:
///
/// | Swift Type | Schema |
/// |---|---|
/// | `String` | `.string()` |
/// | `Int`, `Int32`, `Int64`, etc. | `.integer()` |
/// | `Double`, `Float`, `CGFloat`, `Decimal` | `.number()` |
/// | `Bool` | `.boolean()` |
/// | `Date` | `.string(description: "ISO 8601 date-time")` |
/// | `URL` | `.string(description: "URL")` |
/// | `UUID` | `.string(description: "UUID")` |
/// | `[Element]` | `.array(items: <element schema>)` |
/// | `Optional<T>` | Same schema as `T`, excluded from `required` |
/// | `enum` with `String` raw values | `.string(enumValues: [...])` |
/// | Any other named type | `.from(T.self)` (assumes `JSONConvertible`) |
///
/// **Usage**
/// ```swift
/// @JSONSchema
/// struct Person: Codable {
///     let name: String
///     let age: Int
///     let email: String?  // optional → not in required[]
///
///     enum Status: String, Codable { case active, inactive }
///     let status: Status  // → .string(enumValues: ["active", "inactive"])
/// }
/// ```
///
/// The macro must be applied to a `struct`. Applying it to `class`, `enum`, or `actor`
/// produces a compile-time error.
@attached(extension, conformances: JSONConvertible, names: named(jsonSchema))
public macro JSONSchema() = #externalMacro(module: "JSONKitMacroPlugin", type: "JSONConvertibleMacro")
